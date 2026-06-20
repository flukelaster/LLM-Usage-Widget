using System.Text.Json;
using System.Text.Json.Serialization;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Settings;

/// <summary>How the tray item is rendered (orthogonal to which provider it focuses on).</summary>
public enum MenuBarDisplay { ProviderIconAndPercent, GaugeAndPercent, IconOnly }

/// <summary>User-facing settings, persisted as JSON under <c>%APPDATA%\LLMUsageWidget</c>. Providers
/// are enabled-by-default — we store the *disabled* set, so a new provider shows up automatically.</summary>
public sealed class SettingsModel
{
    public HashSet<string> DisabledProviders { get; set; } = new();
    public int PollIntervalSeconds { get; set; } = 300;
    public MenuBarDisplay MenuBarDisplay { get; set; } = MenuBarDisplay.ProviderIconAndPercent;
    /// <summary>Which provider the tray focuses on; null = whichever is closest to full.</summary>
    public string? MenuBarProvider { get; set; }
    public bool NotificationsEnabled { get; set; } = true;

    [JsonIgnore] public string? FilePath { get; private set; }

    public bool IsEnabled(ProviderId id) => !DisabledProviders.Contains(id.RawValue);

    public void SetEnabled(ProviderId id, bool enabled)
    {
        if (enabled) DisabledProviders.Remove(id.RawValue);
        else DisabledProviders.Add(id.RawValue);
    }

    public static SettingsModel Load()
    {
        string path = DefaultPath();
        try
        {
            if (File.Exists(path) && JsonSerializer.Deserialize<SettingsModel>(File.ReadAllText(path)) is { } loaded)
            {
                loaded.FilePath = path;
                return loaded;
            }
        }
        catch { /* fall through to defaults */ }
        return new SettingsModel { FilePath = path };
    }

    public void Save()
    {
        try
        {
            string path = FilePath ?? DefaultPath();
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { /* best-effort */ }
    }

    private static string DefaultPath() =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "LLMUsageWidget", "settings.json");
}
