using System;
using Godot;
using Chickensoft.LogicBlocks;
using KaijuBreakdown.Menu;
using KaijuBreakdown.Systems;

namespace KaijuBreakdown;

public partial class Main : Node2D
{
    private const string IntroScene = "res://narrative/IntroDialogue.tscn";

    private MenuLogic _logic = null!;
    private LogicBlock.Binding _binding = null!;

    private Control _mainMenu = null!;
    private Control _settingsMenu = null!;
    private OptionButton _resolutionOption = null!;
    private CheckButton _fullscreenCheck = null!;

    public override void _Ready()
    {
        _mainMenu = GetNode<Control>("MenuLayer/MainMenu");
        _settingsMenu = GetNode<Control>("MenuLayer/SettingsMenu");
        _resolutionOption = GetNode<OptionButton>("MenuLayer/SettingsMenu/Panel/Margin/VBox/ResRow/ResolutionOption");
        _fullscreenCheck = GetNode<CheckButton>("MenuLayer/SettingsMenu/Panel/Margin/VBox/FullscreenCheck");

        _logic = new MenuLogic();
        _binding = _logic.Bind();
        _binding
            .OnState<MenuState.MainMenu>(_ => ShowSettings(false))
            .OnState<MenuState.Settings>(_ => ShowSettings(true))
            .OnOutput<MenuState.Output.StartGameRequested>(
                (in MenuState.Output.StartGameRequested _) => GetTree().ChangeSceneToFile(IntroScene))
            .OnOutput<MenuState.Output.QuitGameRequested>(
                (in MenuState.Output.QuitGameRequested _) => GetTree().Quit());

        GetNode<Button>("MenuLayer/MainMenu/Panel/Margin/VBox/StartButton").Pressed +=
            () => _logic.Input(new MenuState.Input.StartGame());
        GetNode<Button>("MenuLayer/MainMenu/Panel/Margin/VBox/SettingsButton").Pressed +=
            () => _logic.Input(new MenuState.Input.OpenSettings());
        GetNode<Button>("MenuLayer/MainMenu/Panel/Margin/VBox/QuitButton").Pressed +=
            () => _logic.Input(new MenuState.Input.QuitGame());
        GetNode<Button>("MenuLayer/SettingsMenu/Panel/Margin/VBox/ButtonRow/ApplyButton").Pressed += OnApplyPressed;
        GetNode<Button>("MenuLayer/SettingsMenu/Panel/Margin/VBox/ButtonRow/BackButton").Pressed +=
            () => _logic.Input(new MenuState.Input.CloseSettings());
        _fullscreenCheck.Toggled += on => _resolutionOption.Disabled = on;

        PopulateSettingsControls();
        _logic.Start<MenuState.MainMenu>();
    }

    public override void _ExitTree()
    {
        _binding?.Dispose();
        _logic?.Dispose();
    }

    private void ShowSettings(bool settings)
    {
        _mainMenu.Visible = !settings;
        _settingsMenu.Visible = settings;
        if (settings)
        {
            SyncSettingsControls();
        }
    }

    private void PopulateSettingsControls()
    {
        _resolutionOption.Clear();
        foreach (Vector2I res in GameSettings.Resolutions)
        {
            _resolutionOption.AddItem($"{res.X} x {res.Y}");
        }
        SyncSettingsControls();
    }

    private void SyncSettingsControls()
    {
        GameSettings settings = GameSettings.Instance;
        int index = Array.IndexOf(GameSettings.Resolutions, settings.Resolution);
        _resolutionOption.Selected = index >= 0 ? index : 0;
        _fullscreenCheck.ButtonPressed = settings.Fullscreen;
        _resolutionOption.Disabled = settings.Fullscreen;
    }

    private void OnApplyPressed()
    {
        GameSettings settings = GameSettings.Instance;
        settings.Fullscreen = _fullscreenCheck.ButtonPressed;
        int selected = _resolutionOption.Selected;
        if (selected >= 0 && selected < GameSettings.Resolutions.Length)
        {
            settings.Resolution = GameSettings.Resolutions[selected];
        }
        settings.Apply();
        settings.Save();
    }
}
