using OpenTK.Graphics.OpenGL;
using System.Drawing;
using System.Drawing.Imaging;

namespace Lighting_Test
{
    class LoadImage
    {
        public static int Load(string filename)
        {
            Bitmap bitmap_0 = (Bitmap)Bitmap.FromFile(filename);
            bitmap_0.RotateFlip(RotateFlipType.RotateNoneFlipY);

            BitmapData data_0 = bitmap_0.LockBits(new Rectangle(0, 0, bitmap_0.Width, bitmap_0.Height),
            ImageLockMode.ReadOnly, System.Drawing.Imaging.PixelFormat.Format24bppRgb);

            int texture = GL.GenTexture();
            GL.BindTexture(TextureTarget.Texture2D, texture);
            GL.TexImage2D(TextureTarget.Texture2D, 0, PixelInternalFormat.Rgb, bitmap_0.Width, bitmap_0.Height, 0, OpenTK.Graphics.OpenGL.PixelFormat.Bgr, PixelType.UnsignedByte, data_0.Scan0);
            GL.GenerateMipmap(GenerateMipmapTarget.Texture2D);

            return texture;
        }
    }
}
