using Chickensoft.LogicBlocks;

namespace KaijuBreakdown.Menu;

public partial class MenuLogic : LogicBlock
{
    public MenuLogic()
    {
        Set(new MenuState.MainMenu());
        Set(new MenuState.Settings());
    }
}
