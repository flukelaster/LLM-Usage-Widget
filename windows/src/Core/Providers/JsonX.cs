using System.Text.Json;

namespace LLMUsageWidget.Core.Providers;

/// <summary>Small tolerant accessors over <see cref="JsonElement"/>, mirroring the lenient
/// dictionary-style decoding the Swift parsers use (field names drift across provider versions).</summary>
internal static class JsonX
{
    internal static bool TryObj(JsonElement parent, string key, out JsonElement value)
    {
        if (parent.ValueKind == JsonValueKind.Object &&
            parent.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.Object)
        {
            value = v;
            return true;
        }
        value = default;
        return false;
    }

    internal static string? Str(JsonElement e, string key) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(key, out var v) &&
        v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    internal static double? Num(JsonElement e, string key) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(key, out var v) &&
        v.ValueKind == JsonValueKind.Number ? v.GetDouble() : null;

    internal static bool? Bool(JsonElement e, string key)
    {
        if (e.ValueKind == JsonValueKind.Object && e.TryGetProperty(key, out var v))
        {
            if (v.ValueKind == JsonValueKind.True) return true;
            if (v.ValueKind == JsonValueKind.False) return false;
        }
        return null;
    }
}
