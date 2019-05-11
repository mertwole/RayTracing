using System;
using OpenTK;
using OpenTK.Input;
using OpenTK.Graphics;
using OpenTK.Graphics.OpenGL4;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using PixelFormat = OpenTK.Graphics.OpenGL4.PixelFormat;

namespace Lighting_Test
{
    class Game : GameWindow
    {
        [STAThread]
        static void Main()
        {
            Game game = new Game();
            game.Run();
        }

        static int window_width = 500;
        static int window_height = 500;
        const int workgroup_size = 10;//max 32
        
        public Game() : base(window_width, window_height, GraphicsMode.Default, "RayTracing")
        {
            VSync = VSyncMode.On;
        }

        protected override void OnResize(EventArgs E)
        {
            base.OnResize(E);
            GL.Viewport(ClientRectangle.X, ClientRectangle.Y, ClientRectangle.Width, ClientRectangle.Height);
        }


        int VAO, VBO;
        int render_shader, compute_shader;
        int texture;

        protected override void OnLoad(EventArgs E)
        {
            base.OnLoad(E);

            float[] vertices =
            {
                -1, -1,  0, 0,
                -1, 1,   0, 1,
                1, 1,    1, 1,
                1, -1,   1, 0
            };

            VAO = GL.GenVertexArray();
            VBO = GL.GenBuffer();

            GL.BindVertexArray(VAO);
            {
                GL.BindBuffer(BufferTarget.ArrayBuffer, VBO);
                GL.BufferData(BufferTarget.ArrayBuffer, vertices.Length * sizeof(float), vertices, BufferUsageHint.StaticDraw);

                GL.VertexAttribPointer(0, 2, VertexAttribPointerType.Float, false, 4 * sizeof(float), 0);
                GL.EnableVertexAttribArray(0);
                GL.VertexAttribPointer(1, 2, VertexAttribPointerType.Float, false, 4 * sizeof(float), 2 * sizeof(float));
                GL.EnableVertexAttribArray(1);

                GL.BindBuffer(BufferTarget.ArrayBuffer, 0);
            }
            GL.BindVertexArray(0);

            GL.PolygonMode(MaterialFace.FrontAndBack, PolygonMode.Fill);

            render_shader = CompileShaders.Compile(new StreamReader("frag_shader.glsl"), new StreamReader("vert_shader.glsl"));
            compute_shader = CompileShaders.CompileComputeShader(new StreamReader("comp_shader.glsl"));

            GL.UseProgram(compute_shader);

            texture = GL.GenTexture();
            GL.BindTexture(TextureTarget.Texture2D, texture);
            GL.TexStorage2D(TextureTarget2d.Texture2D, 1, SizedInternalFormat.Rgba8, window_width, window_height);
            GL.BindImageTexture(0, texture, 0, false, 0, TextureAccess.ReadWrite, SizedInternalFormat.Rgba8);

            GL.Uniform2(GL.GetUniformLocation(compute_shader, "resolution"), new Vector2(window_width, window_height));

            GL.DispatchCompute(window_width / workgroup_size, window_height / workgroup_size, 1);
            //GL.MemoryBarrier(MemoryBarrierFlags.ShaderImageAccessBarrierBit);
        }

        protected override void OnRenderFrame(FrameEventArgs E)
        {
            base.OnRenderFrame(E);

            GL.ClearColor(Color4.Black);
            GL.Clear(ClearBufferMask.ColorBufferBit);

            GL.BindVertexArray(VAO);
            {
                GL.UseProgram(render_shader);

                GL.DrawArrays(PrimitiveType.Quads, 0, 4);
            }
            GL.BindVertexArray(0);

            SwapBuffers();
        }

        protected override void OnKeyDown(KeyboardKeyEventArgs e)
        {
            base.OnKeyDown(e);

            if (e.Key == Key.Escape)
                Environment.Exit(1);

            if(e.Key == Key.S)
            {
                //save render to bitmap
                Bitmap bmp = new Bitmap(window_width, window_height);
                BitmapData data =
                    bmp.LockBits(new Rectangle(0, 0, window_width, window_height), ImageLockMode.WriteOnly,
                    System.Drawing.Imaging.PixelFormat.Format24bppRgb);
                GL.GetTexImage(TextureTarget.Texture2D, 0, PixelFormat.Rgb, PixelType.UnsignedByte, data.Scan0);
                bmp.UnlockBits(data);

                bmp.RotateFlip(RotateFlipType.RotateNoneFlipY);
                bmp.Save("1.bmp", ImageFormat.Bmp);
                Console.WriteLine("saved");
            }
        }
    }
}
