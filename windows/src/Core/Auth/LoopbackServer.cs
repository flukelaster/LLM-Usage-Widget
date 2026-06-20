using System.Net;
using System.Text;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.Core.Auth;

/// <summary>A one-shot loopback HTTP listener that captures an OAuth redirect (used by Codex on
/// 127.0.0.1:1455). Returns the authorization code, then serves a small "you can close this tab" page.</summary>
public static class LoopbackServer
{
    public static async Task<string> WaitForCodeAsync(int port, string expectedState, TimeSpan timeout, CancellationToken ct = default)
    {
        using var listener = new HttpListener();
        listener.Prefixes.Add($"http://127.0.0.1:{port}/");
        listener.Prefixes.Add($"http://localhost:{port}/");
        listener.Start();
        try
        {
            var contextTask = listener.GetContextAsync();
            var completed = await Task.WhenAny(contextTask, Task.Delay(timeout, ct));
            if (completed != contextTask) throw ProviderException.Transport("OAuth callback timed out");

            HttpListenerContext context = await contextTask;
            string? code = context.Request.QueryString["code"];
            string? state = context.Request.QueryString["state"];

            byte[] page = Encoding.UTF8.GetBytes(
                "<html><body style='font-family:sans-serif;background:#0B1120;color:#F8FAFC;text-align:center;padding-top:80px'>" +
                "<h2>Signed in — you can close this tab.</h2></body></html>");
            context.Response.ContentType = "text/html";
            context.Response.ContentLength64 = page.Length;
            await context.Response.OutputStream.WriteAsync(page);
            context.Response.Close();

            if (string.IsNullOrEmpty(code)) throw ProviderException.Unauthorized();
            if (!string.IsNullOrEmpty(expectedState) && state != expectedState) throw ProviderException.Unauthorized();
            return code;
        }
        finally
        {
            listener.Stop();
        }
    }
}
