using System;
using Chickensoft.LogicBlocks;

namespace KaijuBreakdown.Menu;

public abstract partial record MenuState : LogicBlockState
{
    public static class Input
    {
        public readonly record struct OpenSettings;
        public readonly record struct CloseSettings;
        public readonly record struct StartGame;
        public readonly record struct QuitGame;
    }

    public static class Output
    {
        public readonly record struct StartGameRequested;
        public readonly record struct QuitGameRequested;
    }

    public record MainMenu : MenuState,
        IGet<Input.OpenSettings>, IGet<Input.StartGame>, IGet<Input.QuitGame>
    {
        public Type On(in Input.OpenSettings input) => To<Settings>();

        public Type On(in Input.StartGame input)
        {
            Output(new Output.StartGameRequested());
            return ToSelf();
        }

        public Type On(in Input.QuitGame input)
        {
            Output(new Output.QuitGameRequested());
            return ToSelf();
        }
    }

    public record Settings : MenuState, IGet<Input.CloseSettings>
    {
        public Type On(in Input.CloseSettings input) => To<MainMenu>();
    }
}
