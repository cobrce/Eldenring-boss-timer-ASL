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

    #region Update textboxes
    
    vars.prevBoss = (Action<TimeSpan>)((time)=>
    {
        if (vars.textboxes[0] == null)
        {
            vars.logt("previous boss textbox","not found");
        }
        else
        {
            vars.textboxes[0].Settings.Text1 = "Previous boss";
            vars.textboxes[0].Settings.Text2 = new DateTime(time.Ticks).ToString("HH:mm:ss.ff");
        }

    });

    vars.displayDeathCounter = (Action<int>)((counter) =>
    {

        if (vars.textboxes[1] == null)
        {
            vars.logt("previous boss textbox","not found");
        }
        else
        {
            vars.textboxes[1].Settings.Text1 = "Death counter";
            vars.textboxes[1].Settings.Text2 = counter.ToString();
        }

    });
    #endregion

    #region search for textbox
    var mainwindow = Process.GetCurrentProcess().MainWindowHandle;
    dynamic form = Form.FromHandle(mainwindow);
    vars.textboxes = new object[2];
    
    int i = 0;
    foreach (var comp in form.CurrentState.Layout.Components)
    {
        var name = comp.ToString();
        if (name.Contains("Text"))
        {
            switch(i++)
            {
                case 0:
                    vars.logt("previous boss textbox", "found"); 
                    vars.textboxes[0] = comp;
                    break;
                case 1:
                    vars.logt("death counter textbox", "found");
                    vars.textboxes[1] = comp;
                    break;
                default:
                    vars.logt("extra textbox","found");
                break;
            };
        }
    }
    vars.prevBoss(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
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


