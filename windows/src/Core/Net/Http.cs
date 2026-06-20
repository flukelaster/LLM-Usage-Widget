using System.Net;
using System.Text.Json.Serialization;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Net;

/// <summary>The token endpoints' JSON response shape (snake_case).</summary>
public sealed class OAuthTokenResponse
{
    [JsonPropertyName("access_token")] public string AccessToken { get; set; } = "";
    [JsonPropertyName("refresh_token")] public string? RefreshToken { get; set; }
    [JsonPropertyName("id_token")] public string? IdToken { get; set; }
    [JsonPropertyName("expires_in")] public double? ExpiresIn { get; set; }
}

/// <summary>Shared HTTP for usage GETs and OAuth POSTs, mapping status codes to
/// <see cref="ProviderException"/> the way the macOS app's URLSession wrappers do.</summary>
public static class Http
{
    private static readonly HttpClient Client = new() { Timeout = TimeSpan.FromSeconds(30) };

    /// <summary>GET returning the raw body, throwing a mapped <see cref="ProviderException"/> on failure.</summary>
    public static async Task<byte[]> GetAsync(HttpRequestMessage request)
    {
        HttpResponseMessage response;
        try { response = await Client.SendAsync(request); }
        catch (Exception e) { throw ProviderException.Transport(e.Message); }

        using (response)
        {
            if (response.StatusCode == HttpStatusCode.Unauthorized) throw ProviderException.Unauthorized();
            if ((int)response.StatusCode == 429)
                throw ProviderException.RateLimited(response.Headers.RetryAfter?.Delta);
            if (!response.IsSuccessStatusCode) throw ProviderException.Transport($"HTTP {(int)response.StatusCode}");
            return await response.Content.ReadAsByteArrayAsync();
        }
    }

    /// <summary>POST returning the raw body (used by OAuth token/device endpoints).</summary>
    public static async Task<byte[]> PostAsync(HttpRequestMessage request)
    {
        HttpResponseMessage response;
        try { response = await Client.SendAsync(request); }
        catch (Exception e) { throw ProviderException.Transport(e.Message); }

        using (response)
        {
            byte[] body = await response.Content.ReadAsByteArrayAsync();
            if (response.StatusCode == HttpStatusCode.Unauthorized) throw ProviderException.Unauthorized();
            if (!response.IsSuccessStatusCode) throw ProviderException.Transport($"HTTP {(int)response.StatusCode}");
            return body;
        }
    }

    public static string FormEncode(IEnumerable<KeyValuePair<string, string>> form) =>
        string.Join("&", form.Select(kv => $"{Uri.EscapeDataString(kv.Key)}={Uri.EscapeDataString(kv.Value)}"));
}
