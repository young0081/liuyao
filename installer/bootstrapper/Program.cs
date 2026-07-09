using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;

internal static class Program
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBox(IntPtr hWnd, string text, string caption, uint type);

    private const uint MbIconError = 0x00000010;
    private const string ResourceName = "payload.bundle";
    private const string InstallerExe = "liuyao_installer.exe";

    [STAThread]
    private static int Main(string[] args)
    {
        var tempRoot = Path.Combine(
            Path.GetTempPath(),
            "XuanjiLiuyaoInstaller_" + Environment.ProcessId + "_" + Guid.NewGuid().ToString("N")[..8]);

        try
        {
            Directory.CreateDirectory(tempRoot);
            ExtractPayload(tempRoot);

            if (args.Contains("--verify-payload", StringComparer.OrdinalIgnoreCase))
            {
                var gui = Path.Combine(tempRoot, InstallerExe);
                var app = Path.Combine(tempRoot, "payload", "liuyao.exe");
                if (!File.Exists(gui) || !File.Exists(app))
                {
                    throw new FileNotFoundException("Embedded payload verification failed.");
                }
                return 0;
            }

            var installerPath = Path.Combine(tempRoot, InstallerExe);
            if (!File.Exists(installerPath))
            {
                throw new FileNotFoundException("Installer GUI executable was not found.", installerPath);
            }

            using var process = Process.Start(new ProcessStartInfo
            {
                FileName = installerPath,
                WorkingDirectory = tempRoot,
                UseShellExecute = false,
            });

            if (process == null)
            {
                throw new InvalidOperationException("Failed to start installer GUI.");
            }

            process.WaitForExit();
            return process.ExitCode;
        }
        catch (Exception ex)
        {
            MessageBox(IntPtr.Zero, ex.Message, "玄机 · 六爻卦象 安装失败", MbIconError);
            return 1;
        }
        finally
        {
            TryDelete(tempRoot);
        }
    }

    private static void ExtractPayload(string targetDir)
    {
        var asm = Assembly.GetExecutingAssembly();
        using var stream = asm.GetManifestResourceStream(ResourceName)
            ?? throw new InvalidOperationException("Embedded installer payload was not found.");
        using var archive = new ZipArchive(stream, ZipArchiveMode.Read);
        archive.ExtractToDirectory(targetDir, overwriteFiles: true);
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (Directory.Exists(path))
            {
                Directory.Delete(path, recursive: true);
            }
        }
        catch
        {
            // Best-effort cleanup only.
        }
    }
}
