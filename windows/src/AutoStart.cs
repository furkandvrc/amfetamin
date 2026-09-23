using System;
using System.IO;
using System.Security;
using System.Security.Principal;
using System.Text;

namespace Amfetamin
{
    /// <summary>
    /// Auto-start via a Task Scheduler logon task. A task (unlike the Run key)
    /// can start elevated without a UAC prompt.
    /// </summary>
    internal static class AutoStart
    {
        private const string TaskName = "Amfetamin";
        private const string LegacyTaskName = "Amfetamin-AutoStart";

        public static bool IsEnabled() => Shell.Run("schtasks.exe", $"/Query /TN \"{TaskName}\"", 15000).Ok;

        /// <summary>Task registered by the pre-4.0 PowerShell launcher.</summary>
        public static bool LegacyEnabled() => Shell.Run("schtasks.exe", $"/Query /TN \"{LegacyTaskName}\"", 15000).Ok;

        public static void Enable()
        {
            Disable();
            var user = WindowsIdentity.GetCurrent().Name;
            var xml = $@"<?xml version=""1.0"" encoding=""UTF-16""?>
<Task version=""1.2"" xmlns=""http://schemas.microsoft.com/windows/2004/02/mit/task"">
  <RegistrationInfo>
    <Description>amfetamin — connect at logon</Description>
    <Author>{SecurityElement.Escape(AppInfo.Author)}</Author>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>{SecurityElement.Escape(user)}</UserId>
      <Delay>PT15S</Delay>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id=""Author"">
      <UserId>{SecurityElement.Escape(user)}</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>5</Priority>
    <RestartOnFailure>
      <Interval>PT1M</Interval>
      <Count>3</Count>
    </RestartOnFailure>
  </Settings>
  <Actions Context=""Author"">
    <Exec>
      <Command>{SecurityElement.Escape(Paths.InstalledExe)}</Command>
      <Arguments>--autostart</Arguments>
      <WorkingDirectory>{SecurityElement.Escape(Paths.InstallRoot)}</WorkingDirectory>
    </Exec>
  </Actions>
</Task>";
            var file = Path.Combine(Path.GetTempPath(), "amfetamin-task.xml");
            File.WriteAllText(file, xml, Encoding.Unicode);
            try
            {
                var r = Shell.Run("schtasks.exe", $"/Create /TN \"{TaskName}\" /XML \"{file}\" /F", 30000);
                if (!r.Ok) throw new UserFacingException("schtasks: " + r.Output.Trim());
                Log.Info("Auto-start task registered for " + user);
            }
            finally
            {
                try { File.Delete(file); } catch { }
            }
        }

        public static void Disable()
        {
            foreach (var name in new[] { TaskName, LegacyTaskName })
                Shell.Run("schtasks.exe", $"/Delete /TN \"{name}\" /F", 15000);
        }

        /// <summary>Copies the running exe to the install folder so the task path never moves.</summary>
        public static void InstallSelf()
        {
            Paths.EnsureDirs();
            if (Paths.RunningFromInstallDir) return;
            try
            {
                File.Copy(Paths.CurrentExe, Paths.InstalledExe, true);
                var config = Paths.CurrentExe + ".config";
                if (File.Exists(config)) File.Copy(config, Paths.InstalledExe + ".config", true);
            }
            catch (IOException ex)
            {
                // The installed copy is running (e.g. from the tray); it is the same app.
                Log.Warn("Could not update installed copy: " + ex.Message);
            }
        }
    }
}
