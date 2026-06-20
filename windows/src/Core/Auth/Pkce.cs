using System.Security.Cryptography;
using System.Text;

namespace LLMUsageWidget.Core.Auth;

/// <summary>A PKCE code challenge plus an anti-CSRF <c>State</c>, generated per sign-in attempt.</summary>
public sealed record PkceChallenge(string Verifier, string Challenge, string State);

public static class Pkce
{
    public static PkceChallenge Generate()
    {
        string verifier = RandomUrlSafe(32);                                  // 43-char base64url
        string challenge = Base64Url(SHA256.HashData(Encoding.UTF8.GetBytes(verifier)));
        string state = RandomUrlSafe(32);
        return new PkceChallenge(verifier, challenge, state);
    }

    public static string Base64Url(byte[] data) =>
        Convert.ToBase64String(data).Replace('+', '-').Replace('/', '_').TrimEnd('=');

    private static string RandomUrlSafe(int byteCount) =>
        Base64Url(RandomNumberGenerator.GetBytes(byteCount));
}
