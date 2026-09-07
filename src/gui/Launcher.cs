using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace SurfacePro6Tuner
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            try
            {
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string scriptPath = Path.Combine(baseDir, "src", "gui", "App.ps1");

                if (!File.Exists(scriptPath))
                {
                    // Fallback to checking local directory
                    scriptPath = Path.Combine(Directory.GetCurrentDirectory(), "src", "gui", "App.ps1");
                }

                if (!File.Exists(scriptPath))
                {
                    MessageBox.Show(
                        "Die Anwendungsdatei 'src/gui/App.ps1' konnte nicht gefunden werden.\nPfad: " + scriptPath,
                        "Surface Pro 6 Tuner - Fehler",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    return;
                }

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + scriptPath + "\"",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    WorkingDirectory = baseDir
                };

                using (Process proc = Process.Start(psi))
                {
                    proc.WaitForExit();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Unerwarteter Fehler beim Starten des Tuners:\n" + ex.Message,
                    "Surface Pro 6 Tuner - Fehler",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }
    }
}
