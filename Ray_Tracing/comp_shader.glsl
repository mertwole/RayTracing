#version 430 core		
layout( local_size_x = 10, local_size_y = 10) in;

layout (binding = 0, rgba8) uniform image2D Texture;

uniform vec2 resolution;

#define ZERO 0.0001
#define INFINITY 1000000000

bool EqualsZero(double a)
{
	return ((a > -ZERO) && (a < ZERO));
}

struct Ray
{
	dvec3 source;
	dvec3 direction;

	double min_value;
	double max_value;
};

struct Raytrace_result
{
	bool intersection;
	dvec3 contact;
	dvec3 normal;
	double t;

	int material_id;
};

struct Sphere
{
	dvec3 center;
	double radius;

	int material_id;
};

struct Triangle
{
	dvec3[3] vertices;

	int material_id;
};

struct Plane
{
	dvec3 normal;
	dvec3 point;

	int material_id;
};

//************************************************************

Raytrace_result TraceWithSphere(Ray ray, Sphere sphere)
{
	Raytrace_result result;

	dvec3 A = sphere.center - ray.source;
	//length(Direction * t + Source - Center) = radius
	// A = center - source
	//t^2 * dot(Direction, Direction) - 2 * t * dot(A, Direction) + dot(A, A) = Radius ^ 2
	//Direction is normalized => dot(Direction, Direction) = 1
	double half_second_k = -dot(A, ray.direction);
	//Discriminant = second_k ^ 2 - 4 * first_k * third_k
	double Discriminant = 4 * (half_second_k * half_second_k - (dot(A, A) - sphere.radius * sphere.radius));

	if(Discriminant < 0)//no intersection
	{
		result.intersection = false;
		return result;
	}

	//roots are (-half_second_k * 2 +- sqrtD) / 2
	double sqrtD = sqrt(Discriminant);
	double t1 = -half_second_k + sqrtD / 2;
	double t2 = -half_second_k - sqrtD / 2;

	if(t2 >= ray.min_value && t2 <= ray.max_value)
	{
		result.t = t2;
	}
	else if(t1 >= ray.min_value && t1 <= ray.max_value)
	{
		result.t = t1;
	}
	else
	{
		result.intersection = false;
		return result;
	}
	
	result.contact = result.t * ray.direction + ray.source;
	result.normal = (result.contact - sphere.center) / sphere.radius;
	result.intersection = true;

	return result;
}

//************************************************************

Raytrace_result TraceWithPlane(Ray ray, Plane plane)
{
	Raytrace_result result;

	//plane equality:
	//Nx(x - x0) + Ny(y - y0) + Nz(z - z0) = 0
	//where N - normal vector to plane
	//V[0](x0, y0, z0) - any point on this plane
	//point on ray = t * Direction + source
	//   =>
	//t = Dot(N, V[0] - Source) / Dot(N, Direction)
	//Dot(N, Direction) == 0 when Normal is perpendicular to direction => Direction parrallel to plane
	double denominator = dot(plane.normal, ray.direction);
	double numerator = dot(plane.normal, plane.point - ray.source);

	if(EqualsZero(denominator)) //ray is parallel to plane 
	{
		if(false)//EqualsZero(numerator))//ray lies on plane
		{
			result.normal = plane.normal;
			result.contact = ray.source + ray.min_value * ray.direction;
			result.intersection = true;
			result.t = ray.min_value;
			return result;
		}

		result.intersection = false;
		return result;
	}

	double t = numerator / denominator;
	
	if(t < ray.min_value || t > ray.max_value)//t is not valid
	{		
		result.intersection = false;
		return result;
	}

	result.intersection = true;
	result.contact = ray.source + ray.direction * t;	
	result.normal = plane.normal;
	result.t = t;

	if(dot(plane.normal, -ray.direction) < 0)//get normal facing to source
		result.normal *= -1;

	return result;
}
 
//************************************************************

Raytrace_result TraceWithTriangle(Ray ray, Triangle triangle)
{
	Raytrace_result result;

	dvec3 normal = normalize(cross(triangle.vertices[0] - triangle.vertices[1], triangle.vertices[0] - triangle.vertices[2]));
	Plane triangle_plane = {normal, triangle.vertices[0], 0};
	result = TraceWithPlane(ray, triangle_plane);

	if(!result.intersection)
	{
		return result;
	}

	for(int i = 0; i < 3; i++)
	{
		int j = i + 1;//second vertex
		if(j > 2) j = 0;
		int k = j + 1;
		if(k > 2) k = 0;//third vertex

		//determine plane P that is parallel to triangle normal & contains JK
		dvec3 P_normal = normalize(cross(triangle.vertices[j] - triangle.vertices[k], triangle_plane.normal));
		//plane equality is P_normal.x * X + P_normal.y * Y + P_normal.z * Z + d = 0
		double d = -dot(P_normal, triangle.vertices[j]);

		double I_side = sign(dot(P_normal, triangle.vertices[i]) + d);
		double Contact_side = sign(dot(P_normal, result.contact) + d);

		if(Contact_side == 0)
			continue;

		if(I_side == Contact_side)
			continue;

		result.intersection = false;
		return result;
	}

	return result;
}

//************************************************************

#define SPHERES_COUNT 3
#define PLANES_COUNT 5
#define TRIANGLES_COUNT 1

Sphere[SPHERES_COUNT] spheres = 
{//center radius material_id
	{dvec3(-2.2, 0, -3), 1, 0},
	{dvec3(0, 0, -3), 1, 1},
	{dvec3(2.2, 0, -3), 1, 2},
	//{dvec3(0, 5003.1, -3), 5000, 4},
	//{dvec3(50004, 0, -3), 50000, 4},
	//{dvec3(-5004, 0, -3), 5000, 4}
};

Plane[PLANES_COUNT] planes = 
{//normal point material_id
	//{normalize(dvec3(0, 1, 0)), dvec3(0, -1, 0), 3},//bottom
	{normalize(dvec3(0, 1, 0)), dvec3(0, 7, 0), 4},//top

	{normalize(dvec3(-1, 0, 0)), dvec3(5, 0, 0), 5},//right
	{normalize(dvec3(1, 0, 0)), dvec3(-5, 0, 0), 6},//left

	{normalize(dvec3(0, 0, 1)), dvec3(0, 0, -5), 4},//back
	{normalize(dvec3(0, 0, 1)), dvec3(0, 0, 4), 4}//front
};

Triangle[TRIANGLES_COUNT] triangles =
{//vec3[3] vertices material_id
	{{vec3(-5, -1, -5), vec3(5, -1, -5), vec3(0, -1, 1)}, 1}
};

//************************************************************

bool RayIntersectsAnything(Ray ray)
{
	for(int i = 0; i < SPHERES_COUNT; i++)
	{
		Raytrace_result res = TraceWithSphere(ray, spheres[i]);

		if(res.intersection)
			return true;
	}

	for(int i = 0; i < PLANES_COUNT; i++)
	{
		Raytrace_result res = TraceWithPlane(ray, planes[i]);

		if(res.intersection)
			return true;
	}

	for(int i = 0; i < TRIANGLES_COUNT; i++)
	{
		Raytrace_result res = TraceWithTriangle(ray, triangles[i]);

		if(res.intersection)
			return true;
	}

	return false;
}

Raytrace_result TraceRay(Ray ray)
{
	double min_t = INFINITY;

	Raytrace_result result;
	result.intersection = false;

	for(int i = 0; i < SPHERES_COUNT; i++)//find sphere with min t
	{
		Raytrace_result res = TraceWithSphere(ray, spheres[i]);

		if(res.intersection && res.t < min_t)
		{
			min_t = res.t;
			result = res;
			result.material_id = spheres[i].material_id;
		}
	}

	for(int i = 0; i < PLANES_COUNT; i++)//find plane with min t
	{
		Raytrace_result res = TraceWithPlane(ray, planes[i]);

		if(res.intersection && res.t < min_t)
		{
			min_t = res.t;
			result = res;
			result.material_id = planes[i].material_id;
		}
	}

	for(int i = 0; i < TRIANGLES_COUNT; i++)//find plane with min t
	{
		Raytrace_result res = TraceWithTriangle(ray, triangles[i]);

		if(res.intersection && res.t < min_t)
		{
			min_t = res.t;
			result = res;
			result.material_id = triangles[i].material_id;
		}
	}

	return result;
}

//************************************************************

dvec3 view_point = dvec3(0, 0, 3);
double view_distance = 0.7;
double pitch = 0;//x
double yaw = 0;//y
dvec2 viewport = dvec2(1.5, 1.5);

//*************************lighting***************************
dvec3 ambient = dvec3(0.4);

#define REFLECTION_DEPTH 5

struct Material
{
	double reflection;
	dvec3 color;
	double shininess;
};

Material[7] materials = 
{
	{0.1, dvec3(1, 1, 1), 32},
	{0.15, dvec3(0.1, 0.1, 1), 256},
	{0.1, dvec3(1, 1, 1), 32},
	{0.1, dvec3(0, 0.5, 0), 32},
	{0, dvec3(0.5, 0.5, 0.5), 0},
	{0, dvec3(0.5, 0.2, 0.2), 32},
	{0, dvec3(0.5, 0.1, 0.1), 32}
};

struct Directional_light
{
	dvec3 direction;

	dvec3 diffuse_color;
	dvec3 specular_color;
};

struct Point_light
{
	dvec3 position;

	dvec3 diffuse_color;
	dvec3 specular_color;

	float constant;
	float linear;
	float quadratic;
};

#define DIRECTIONAL_LIGHTS_COUNT 1
#define POINT_LIGHTS_COUNT 1

Directional_light[DIRECTIONAL_LIGHTS_COUNT] directional_lights = 
{
	{normalize(dvec3(0, -10, 0)), dvec3(0), dvec3(0)}
};

Point_light[POINT_LIGHTS_COUNT] point_lights = 
{
	//{dvec3(-3.99, 2, -3), dvec3(2, 0, 0), dvec3(0.5, 0, 0), 1, 0.2, 0.02},
	{dvec3(0, 4.9, -3), dvec3(4), dvec3(0, 0.5, 0), 1, 0.2, 0.02}
};

//************************************************************

dvec3 GetLightFromContact(Raytrace_result result)
{	
	if(!result.intersection)
		return dvec3(0);

	Material material = materials[result.material_id];
	
	dvec3 diffuse;
	dvec3 specular;

	dvec3 observer_vector = normalize(view_point - result.contact);//from contact to view point
	//***************directional***********************
	for(int i = 0; i < DIRECTIONAL_LIGHTS_COUNT; i++)
	{		
		dvec3 light_vector = -directional_lights[i].direction;//from contact to light source

		Ray ray_to_light = Ray(result.contact, light_vector, ZERO, INFINITY);
		bool shadow = RayIntersectsAnything(ray_to_light);

		if(!shadow)
		{
			diffuse += max(dot(light_vector, result.normal), 0) * directional_lights[i].diffuse_color;
			specular += pow(float(max(dot(reflect(observer_vector, result.normal), -light_vector), 0)) , float(material.shininess)) * directional_lights[i].specular_color;
		}
	}
	//***********************point**********************
	for(int i = 0; i < POINT_LIGHTS_COUNT; i++)
	{		
		dvec3 light_vector = normalize(point_lights[i].position - result.contact);//from contact to light source

		Ray ray_to_light = Ray(result.contact, light_vector, ZERO, length(point_lights[i].position - result.contact));
		bool shadow = RayIntersectsAnything(ray_to_light);

		if(!shadow)
		{
			double dist = length(result.contact - point_lights[i].position);
			double distance_influence = 1 / (point_lights[i].constant + dist * point_lights[i].linear + dist * dist * point_lights[i].quadratic);

			diffuse += max(dot(light_vector, result.normal), 0) * point_lights[i].diffuse_color * distance_influence;

			specular += pow(float(max(dot(reflect(observer_vector, result.normal), -light_vector), 0)) , float(material.shininess)) 
			* point_lights[i].specular_color * distance_influence;
		}
	}
	//***************************************************

	dvec3 color = (ambient + ((diffuse + specular) / 2) / (POINT_LIGHTS_COUNT + DIRECTIONAL_LIGHTS_COUNT) ) * material.color;

	return color;
}

dvec3 GetColor(Ray current_ray)
{
	Ray ray = current_ray;
	//ray.direction *= -1;

	dvec3[REFLECTION_DEPTH] self_colors;
	double[REFLECTION_DEPTH] reflections;
	int last_reflected;

	for(int i = 0; i < REFLECTION_DEPTH; i++)
	{
		Raytrace_result result = TraceRay(ray);	

		//if(!result.intersection)
		//{
		//	last_reflected = i - 1;
		//	break;
		//}

		self_colors[i] = GetLightFromContact(result);
		reflections[i] = materials[result.material_id].reflection;

		ray = Ray(result.contact, reflect(ray.direction, result.normal), ZERO, INFINITY);
	}
	
	last_reflected = REFLECTION_DEPTH - 1;

	dvec3 color;

	for(int i = last_reflected; i >= 0; i--)
	{		
		color = (reflections[i]) * color + (1 - reflections[i]) * self_colors[i]; 
	}

	return color;
}


void main()
{ 
	//********************test*********************************************
	Ray current_ray;
	current_ray.source = view_point;	

	dvec3 watch_dot = view_point;
	watch_dot.z -= view_distance;//forward z
	watch_dot.x += ((gl_GlobalInvocationID.x / resolution.x) - 0.5) * viewport.x;
	watch_dot.y += ((gl_GlobalInvocationID.y / resolution.y) - 0.5) * viewport.y;

	current_ray.direction = normalize(watch_dot - view_point);
	current_ray.min_value = length(watch_dot - view_point);
	current_ray.max_value = INFINITY;
	//**********************************************************************
		
	imageStore(Texture, ivec2(gl_GlobalInvocationID.xy), vec4(GetColor(current_ray), 1));
}