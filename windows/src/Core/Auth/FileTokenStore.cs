using System.Security.Cryptography;
using System.Text.Json;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Auth;

/// <summary>Stores each provider's <see cref="OAuthToken"/> as a file under the app data directory,
/// encrypted with Windows DPAPI (per-user). On non-Windows hosts (dev only) the bytes are stored
/// as-is, so the same code path compiles and runs everywhere.</summary>
public sealed class FileTokenStore : ITokenStore
{
    private readonly string _directory;

    public FileTokenStore(string directory)
    {
        _directory = directory;
        Directory.CreateDirectory(_directory);
    }

    /// <summary>Default location: <c>%APPDATA%\LLMUsageWidget</c> on Windows, otherwise the
    /// platform's application-data folder.</summary>
    public static FileTokenStore Default() =>
        new(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "LLMUsageWidget"));

    private string PathFor(ProviderId id) => Path.Combine(_directory, $"token-{id.RawValue}.bin");

    public OAuthToken? Get(ProviderId id)
    {
        string path = PathFor(id);
        if (!File.Exists(path)) return null;
        try
        {
            byte[] plain = Unprotect(File.ReadAllBytes(path));
            return JsonSerializer.Deserialize<OAuthToken>(plain);
        }
        catch
        {
            return null;
        }
    }

    public void Save(ProviderId id, OAuthToken token)
    {
        byte[] plain = JsonSerializer.SerializeToUtf8Bytes(token);
        File.WriteAllBytes(PathFor(id), Protect(plain));
    }

    public void Clear(ProviderId id)
    {
        string path = PathFor(id);
        if (File.Exists(path)) File.Delete(path);
    }

    private static byte[] Protect(byte[] data) =>
        OperatingSystem.IsWindows() ? ProtectedData.Protect(data, null, DataProtectionScope.CurrentUser) : data;

    private static byte[] Unprotect(byte[] data) =>
        OperatingSystem.IsWindows() ? ProtectedData.Unprotect(data, null, DataProtectionScope.CurrentUser) : data;
}
