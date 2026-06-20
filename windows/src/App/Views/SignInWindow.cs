using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;

namespace LLMUsageWidget.App.Views;

/// <summary>Minimal sign-in helper window: a paste box for the Claude code flow, and a
/// code-display window for the Copilot device flow. All UI work is marshaled to the UI thread.</summary>
public sealed class SignInWindow : Window
{
    private SignInWindow()
    {
        Width = 380;
        SizeToContent = SizeToContent.Height;
        CanResize = false;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = new SolidColorBrush(Color.Parse("#0B1120"));
    }

    /// <summary>Show a paste box and resolve with the entered code (or null if cancelled).</summary>
    public static async Task<string?> PromptCodeAsync(string provider, string instructions)
    {
        var tcs = new TaskCompletionSource<string?>();
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            var box = new TextBox { PlaceholderText = "Paste code here" };
            var connect = new Button { Content = "Connect", HorizontalAlignment = HorizontalAlignment.Right };
            var win = new SignInWindow { Title = $"Sign in — {provider}" };

            connect.Click += (_, _) => { tcs.TrySetResult(string.IsNullOrWhiteSpace(box.Text) ? null : box.Text); win.Close(); };
            win.Closed += (_, _) => tcs.TrySetResult(null);
            win.Content = new StackPanel
            {
                Margin = new(18),
                Spacing = 10,
                Children =
                {
                    new TextBlock { Text = provider, FontSize = 16, FontWeight = FontWeight.SemiBold, Foreground = Brushes.White },
                    new TextBlock { Text = instructions, TextWrapping = TextWrapping.Wrap, Foreground = new SolidColorBrush(Color.Parse("#94A3B8")) },
                    box,
                    connect,
                },
            };
            win.Show();
        });
        return await tcs.Task;
    }

    /// <summary>Show the device user-code and verification URL; close via <see cref="CloseFromHost"/>.</summary>
    public static SignInWindow ShowDevice(string provider, string userCode, Uri url, string instructions) =>
        Dispatcher.UIThread.Invoke(() =>
        {
            var win = new SignInWindow { Title = $"Sign in — {provider}" };
            win.Content = new StackPanel
            {
                Margin = new(18),
                Spacing = 10,
                Children =
                {
                    new TextBlock { Text = provider, FontSize = 16, FontWeight = FontWeight.SemiBold, Foreground = Brushes.White },
                    new TextBlock { Text = instructions, TextWrapping = TextWrapping.Wrap, Foreground = new SolidColorBrush(Color.Parse("#94A3B8")) },
                    new SelectableTextBlock { Text = userCode, FontSize = 28, FontWeight = FontWeight.Bold, Foreground = new SolidColorBrush(Color.Parse("#32D74B")), HorizontalAlignment = HorizontalAlignment.Center },
                    new TextBlock { Text = url.ToString(), Foreground = new SolidColorBrush(Color.Parse("#64748B")), HorizontalAlignment = HorizontalAlignment.Center },
                    new TextBlock { Text = "Waiting for authorization…", Foreground = new SolidColorBrush(Color.Parse("#94A3B8")), HorizontalAlignment = HorizontalAlignment.Center },
                },
            };
            win.Show();
            return win;
        });

    public void CloseFromHost() => Dispatcher.UIThread.Post(Close);
}
