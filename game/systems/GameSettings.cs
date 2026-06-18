using Godot;

namespace KaijuBreakdown.Systems;

public partial class GameSettings : Node
{
    public static GameSettings Instance { get; private set; } = null!;

    private const string SettingsPath = "user://settings.cfg";
    private const string DisplaySection = "display";
    private const string ResolutionKey = "resolution";
    private const string FullscreenKey = "fullscreen";

    // some basic resolutions for now, need to think about strategy later
    public static readonly Vector2I[] Resolutions =
    {
        new(1080, 720),
        new(1440, 960),
        new(1920, 1280),
        new(2400, 1600),
    };

    public Vector2I Resolution { get; set; } = new(1920, 1280);
    public bool Fullscreen { get; set; }

    public override void _EnterTree() => Instance = this;

    public override void _Ready()
    {
        Load();
        Apply();
    }

    public void Load()
    {
        var config = new ConfigFile();
        if (config.Load(SettingsPath) != Error.Ok)
        {
            return; // No settings file yet; keep defaults.
        }

        Resolution = (Vector2I)config.GetValue(DisplaySection, ResolutionKey, Resolution);
        Fullscreen = (bool)config.GetValue(DisplaySection, FullscreenKey, Fullscreen);
    }

    public void Save()
    {
        var config = new ConfigFile();
        config.SetValue(DisplaySection, ResolutionKey, Resolution);
        config.SetValue(DisplaySection, FullscreenKey, Fullscreen);
        config.Save(SettingsPath);
    }

    public void Apply()
    {
        if (Fullscreen)
        {
            DisplayServer.WindowSetMode(DisplayServer.WindowMode.Fullscreen);
            return;
        }

        DisplayServer.WindowSetMode(DisplayServer.WindowMode.Windowed);
        DisplayServer.WindowSetSize(Resolution);

        int screen = DisplayServer.WindowGetCurrentScreen();
        Vector2I screenPos = DisplayServer.ScreenGetPosition(screen);
        Vector2I screenSize = DisplayServer.ScreenGetSize(screen);
        DisplayServer.WindowSetPosition(screenPos + ((screenSize - Resolution) / 2));
    }
}
