using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using LLMUsageWidget.App.Theming;
using LLMUsageWidget.App.Views;
using LLMUsageWidget.Core.Domain;

namespace LLMUsageWidget.App;

public partial class App : Application
{
    private AppHost? _host;
    private PopoverWindow? _popover;
    private TrayIcon? _tray;

    public override void Initialize() => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            // Tray-only app: no main window, runs until the user quits.
            desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;

            _host = new AppHost();
            _popover = new PopoverWindow { DataContext = _host.Popover };
            _popover.Deactivated += (_, _) => _popover?.Hide();
            _host.Updated += () => { if (_tray is not null && _host is not null) _tray.ToolTipText = _host.MenuBarText(); };

            TrySetupTray(desktop);
            _host.Start();
        }

        base.OnFrameworkInitializationCompleted();
    }

    private void TrySetupTray(IClassicDesktopStyleApplicationLifetime desktop)
    {
        try
        {
            var menu = new NativeMenu();

            var refresh = new NativeMenuItem("Refresh now");
            refresh.Click += (_, _) => { if (_host is not null) _ = _host.RefreshNowAsync(); };
            menu.Items.Add(refresh);

            menu.Items.Add(BuildAccountsMenu());

            var settings = new NativeMenuItem("Settings");
            settings.Click += (_, _) => _host?.OpenSettings();
            menu.Items.Add(settings);

            menu.Items.Add(new NativeMenuItemSeparator());

            var quit = new NativeMenuItem("Quit");
            quit.Click += (_, _) => desktop.Shutdown();
            menu.Items.Add(quit);

            _tray = new TrayIcon { ToolTipText = "LLM Usage", Icon = BuildTrayIcon(), Menu = menu };
            _tray.Clicked += (_, _) => TogglePopover();

            TrayIcon.SetIcons(this, new TrayIcons { _tray });
        }
        catch
        {
            // Tray is best-effort (e.g. headless / unsupported session) — the app still runs.
        }
    }

    private NativeMenuItem BuildAccountsMenu()
    {
        var accounts = new NativeMenuItem("Accounts") { Menu = new NativeMenu() };
        if (_host is null) return accounts;

        foreach (var provider in _host.Store.Providers)
        {
            var id = provider.Id;
            var signIn = new NativeMenuItem($"Sign in {provider.DisplayName}");
            signIn.Click += (_, _) => { if (_host is not null) _ = _host.SignInAsync(id); };
            accounts.Menu!.Items.Add(signIn);

            var signOut = new NativeMenuItem($"Sign out {provider.DisplayName}");
            signOut.Click += (_, _) => { if (_host is not null) _ = _host.SignOutAsync(id); };
            accounts.Menu!.Items.Add(signOut);
        }
        return accounts;
    }

    private void TogglePopover()
    {
        if (_popover is null) return;
        if (_popover.IsVisible)
        {
            _popover.Hide();
            return;
        }

        var screen = _popover.Screens.Primary ?? _popover.Screens.All.FirstOrDefault();
        if (screen is not null)
        {
            var area = screen.WorkingArea;
            int width = (int)(340 * screen.Scaling);
            _popover.Position = new PixelPoint(
                area.X + area.Width - width - (int)(12 * screen.Scaling),
                area.Y + (int)(8 * screen.Scaling));
        }
        _popover.Show();
        _popover.Activate();
    }

    private static WindowIcon BuildTrayIcon()
    {
        using var rtb = new RenderTargetBitmap(new PixelSize(32, 32), new Vector(96, 96));
        using (var ctx = rtb.CreateDrawingContext())
        {
            ctx.DrawEllipse(null, new Pen(Palette.Warn, 4), new Point(16, 16), 11, 11);
        }
        using var ms = new MemoryStream();
        rtb.Save(ms);
        ms.Position = 0;
        return new WindowIcon(ms);
    }
}
