state("eldenring")
{
}

startup
{
    vars.shouldReset = false;

    #region log
    vars.log = (Action<String>) ((text) =>
    {
        print(String.Format("[ER boss timer] {0}",text));
    });
    vars.logt = (Action<String,String>)((title,text)=>
    {
        print(String.Format("[ER boss timer : {0}] {1}",title,text));
    });
    #endregion
    
    #region Create/Find Textboxes
    var controls = new Dictionary<String,LiveSplit.UI.Components.ILayoutComponent>();

    vars.setText = (Action<String,String>)((Value1,Value2)=>
    {
        LiveSplit.UI.Components.ILayoutComponent control = null;

        if (!controls.TryGetValue(Value1,out control))
        {
            foreach (var c in timer.Layout.LayoutComponents) // try to find it in layout
            {
                try
                {
                    dynamic comp = c.Component;
                    if (comp.Settings.Text1 == Value1)
                    {
                            controls[Value1] = control =  c;
                            vars.logt("control found", Value1);
                            break;
                    }
                }
                catch 
                {
                    
                }
            }
            if (control == null)
            {
                controls[Value1]= control = LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent("LiveSplit.Text.dll",timer);
                vars.logt("control created", Value1);
            }
            if (!timer.Layout.LayoutComponents.Contains(control))
            {
                vars.logt("control added", Value1);
                timer.Layout.LayoutComponents.Add(control);
            }
        }
        dynamic component = control.Component;
        component.Settings.Text1 = Value1;
        component.Settings.Text2 = Value2;    
    });

    #endregion

    #region Update textboxes
    
    vars.prevBoss = (Action<TimeSpan>)((time)=>
    {
        vars.setText("Previous boss",new DateTime(time.Ticks).ToString("HH:mm:ss.ff"));
    });

    vars.displayDeathCounter = (Action<int>)((counter) =>
    {
        vars.setText("Death counter",counter.ToString());

    });
    #endregion

    #region Correct timing method
         
    if (timer.CurrentTimingMethod != TimingMethod.GameTime)
    {
        if (DialogResult.Yes ==  
            MessageBox.Show("This split uses GameTime as timing method, switch now?",
            "LiveSplit : Eldenring boss timer",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question))
        {
            timer.CurrentTimingMethod = TimingMethod.GameTime;
        }
    }
    #endregion

    #region AOB pattern scan functions
    // Pattern copied from GrandArchives cheat engine table
    vars.sigScanTarget = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 48 85 C0 74 05 48 8B 40 58 C3 C3");
    vars.ReadPointer = (Func<Process,IntPtr,IntPtr>)((proc,ptr) =>
    {
        return proc.ReadPointer(ptr);
    });

    // credits to https://github.com/drtchops/asl/blob/master/dxmd.asl
    vars.ReadOffset = (Func<Process, IntPtr, int, int, IntPtr>)((proc, ptr, offsetSize, remainingBytes) =>
        {
            byte[] offsetBytes;
            if (ptr == IntPtr.Zero || !proc.ReadBytes(ptr, offsetSize, out offsetBytes))
                return IntPtr.Zero;

            int offset;
            switch (offsetSize)
            {
                case 1:
                    offset = offsetBytes[0];
                    break;
                case 2:
                    offset = BitConverter.ToInt16(offsetBytes, 0);
                    break;
                case 4:
                    offset = BitConverter.ToInt32(offsetBytes, 0);
                    break;
                default:
                    throw new Exception("Unsupported offset size");
            }
            return ptr + offsetSize + remainingBytes + offset;
        });
    #endregion

    #region init controls
    vars.prevBoss(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
    vars.displayDeathCounter(0);
    #endregion
}

init
{
    vars.logt("Init","");
    var module = modules.FirstOrDefault(m => m.ModuleName.ToLower() == "eldenring.exe");
    var scanner = new SignatureScanner(game, module.BaseAddress, module.ModuleMemorySize);
    var codeLocation = scanner.Scan(vars.sigScanTarget);
    vars.logt("pattern found", codeLocation.ToString("X"));
    	
    var pointer = vars.ReadOffset(game,codeLocation,4,0);
    vars.logt("pointer", pointer.ToString("X"));

    var GameDataMan = vars.ReadPointer(game,pointer);
    vars.logt("GameDataMan", GameDataMan.ToString("X"));
    
    vars.isBossFight = new MemoryWatcher<byte>(GameDataMan+0xC0);
    vars.logt("isBossFight", vars.isBossFight.Current.ToString());

    vars.deathCount = new MemoryWatcher<int>(GameDataMan+0x94);
    vars.deathCount.Update(game);
    vars.displayDeathCounter(vars.deathCount.Current);
    vars.logt("death count", vars.deathCount.Current.ToString());

}

update
{
    vars.deathCount.Update(game);
	if (vars.deathCount.Current != vars.deathCount.Old)
	{	
        vars.logt("death count", vars.deathCount.Current.ToString());
        vars.displayDeathCounter(vars.deathCount.Current);
	}	
    
	vars.isBossFight.Update(game);
    vars.shouldReset = (vars.isBossFight.Old == 0 && vars.isBossFight.Current == 1);
}

reset
{
    var shouldReset = vars.shouldReset; // resets the timer when a new boss fight begins
    vars.shouldReset = false;
	
	if (shouldReset)
    {
		vars.logt("timer","reset");
        vars.prevBoss(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
    }
    return shouldReset;
}


start
{
	if (vars.isBossFight.Current == 1)
	{
        vars.logt("timer","started");
		return true; // start timer during boss fight (called only when timer is reset)
	}
}

isLoading
{
	if (vars.isBossFight.Current == 0)
	{
        if (vars.isBossFight.Old == 1)
        {
		    vars.logt("timer","paused");
        }
		return true;
	}
}


