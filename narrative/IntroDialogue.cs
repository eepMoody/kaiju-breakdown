using Godot;
using YarnSpinnerGodot;

namespace KaijuBreakdown.Narrative;

public partial class IntroDialogue : Control
{
    private const string DefaultDialogueSystemScene =
        "res://addons/YarnSpinner-Godot/Scenes/DefaultDialogueSystem.tscn";

    private const string YarnProjectPath =
        "res://narrative/KaijuBreakdown.yarnproject";

    private const string OverworldScene =
        "res://overworld/overworld_prototype.tscn";

    [Export] public string StartNode { get; set; } = "Main";

    [Export] public bool GoToOverworldOnComplete { get; set; } = true;

    private DialogueRunner? _runner;
    private bool _completed;

    public override void _Ready()
    {
        var systemScene = GD.Load<PackedScene>(DefaultDialogueSystemScene);
        if (systemScene == null)
        {
            GD.PushError($"IntroDialogue: could not load dialogue system scene at {DefaultDialogueSystemScene}");
            return;
        }

        var system = systemScene.Instantiate();

        _runner = system.GetNodeOrNull<DialogueRunner>("DialogueRunner");
        if (_runner == null)
        {
            GD.PushError("IntroDialogue: DialogueRunner node not found in DefaultDialogueSystem scene.");
            return;
        }

        var project = GD.Load<YarnProject>(YarnProjectPath);
        if (project == null)
        {
            GD.PushError($"IntroDialogue: could not load YarnProject at {YarnProjectPath}. " +
                         "Open the project once in the Godot 4.6 .NET editor to import the .yarnproject.");
            return;
        }

        _runner.SetProject(project);
        _runner.startNode = StartNode;
        _runner.autoStart = true;
        _runner.Connect(DialogueRunner.SignalName.onDialogueComplete,
            Callable.From(OnDialogueComplete));

        AddChild(system);
    }

    private void OnDialogueComplete()
    {
        if (_completed)
        {
            return;
        }

        _completed = true;
        GD.Print("IntroDialogue: dialogue complete.");
        if (GoToOverworldOnComplete)
        {
            GetTree().CallDeferred(SceneTree.MethodName.ChangeSceneToFile, OverworldScene);
        }
    }
}
