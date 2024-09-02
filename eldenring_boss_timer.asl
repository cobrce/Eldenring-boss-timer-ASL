state("eldenring")
{
}

startup
{
    vars.ShouldReset = false;
    vars.ER = null;

    Console.Clear();
    Console.WriteLine(DateTime.Now.ToString());

    #region log

    vars.Msgb = (Action<String>)((text) =>
    {
        MessageBox.Show(text,"SoulMemScript",MessageBoxButtons.OK,MessageBoxIcon.Information);
    });

    vars.Log = (Action<String>) ((text) =>
    {
        print(String.Format("[ER boss timer] {0}",text));
        Console.WriteLine(String.Format("[ER boss timer] {0}",text));
    });
    vars.Logt = (Action<String,String>)((title,text)=>
    {
        print(String.Format("[ER boss timer : {0}] {1}",title,text));
        Console.WriteLine(String.Format("[ER boss timer : {0}] {1}",title,text));

    });
    #endregion
    
    #region Create/Find Textboxes
    var controls = new Dictionary<String,LiveSplit.UI.Components.ILayoutComponent>();
    vars.GetControl = (Func<String,object>)((controlName)=>
    {
        LiveSplit.UI.Components.ILayoutComponent control = null;
        if (!controls.TryGetValue(controlName,out control))
        {
            foreach (var c in timer.Layout.LayoutComponents) // try to find it in layout
            {
                try
                {
                    dynamic comp = c.Component;
                    if (comp.Settings.Text1 == controlName)
                    {
                            controls[controlName] = control =  c;
                            vars.Logt("control found", controlName);
                            break;
                    }
                }
                catch 
                {
                    
                }
            }
            if (control == null)
            {
                controls[controlName]= control = LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent("LiveSplit.Text.dll",timer);
                vars.Logt("control created", controlName);
            }
            if (!timer.Layout.LayoutComponents.Contains(control))
            {
                vars.Logt("control added", controlName);
                timer.Layout.LayoutComponents.Add(control);
            }
        }
        return (object)control;

    });

    vars.CreateSeparator = (Action<bool>)((ignoreExistant)=>
    {
        bool found = false;
            foreach (var c in timer.Layout.LayoutComponents)
            {
                if(c.Component is LiveSplit.UI.Components.SeparatorComponent)
                {
                    vars.Logt("Sperator", "Existing");
                    found = true;
                    break;
                }
        }
        if (ignoreExistant || !found)
        {
            var compo = new LiveSplit.UI.Components.LayoutComponent("",new LiveSplit.UI.Components.SeparatorComponent());
            timer.Layout.LayoutComponents.Add(compo);
            vars.Logt("Separator","Created");
        }
    });
    #endregion

    #region Update textboxes

    vars.SetText = (Action<String,String>)((Value1,Value2)=>
    {
        dynamic component = vars.GetControl(Value1).Component;
        component.Settings.Text1 = Value1;
        if (Value2!=null)
            component.Settings.Text2 = Value2;    
    });


    
    vars.PrevBossTime = (Action<object>)((time)=>
    {
        vars.SetText("Previous fight time",time == null ? null : new DateTime(((TimeSpan)time).Ticks).ToString("HH:mm:ss.ff"));
    });


    vars.DisplayDeathCounter = (Action<int?>)((counter) =>
    {
        vars.SetText("Death counter",counter == null ? null : counter.ToString());

    });

    vars.PreviousKillTime = (Action<object>)((time)=>
    {
        vars.SetText("Previous boss time",time ==null ? null : new DateTime(((TimeSpan)time).Ticks).ToString("HH:mm:ss.ff"));
    });

    vars.PrevBossName = (Action<String>)((name)=>
    {
        vars.SetText("=",name);
    });

    vars.SetNumOfGreatRunes = (Action<int?>)((number)=>
    {
        vars.SetText("Great runes",number == null ? null : number.ToString());
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

    vars.ReadInt = (Func<Process,IntPtr,Int32>)((proc,ptr) =>
    {
        return proc.ReadValue<Int32>(ptr);
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

    #region Load soulmemory.dll

    vars.ResetBosses = (Action)(()=>
    {
        vars.RemainingBoss = new List<uint>();
        foreach(var kvp in vars.bossNames)
        {
            vars.RemainingBoss.Add(kvp.Key);
        }
    });

    vars.LoadSoulMem = (Func<bool>)(()=> 
    {
        try
        {
            var dir = Path.GetDirectoryName(timer.GetType().Assembly.Location);
            var location = Path.Combine(dir,"components","soulmemory.dll");
            if (!File.Exists(location))
            {
                vars.err = "soulmemory.dll not found";
                return false;
            }
            
            vars.Logt("soulmemory.dll", "found");

            vars.err = "Can't load soulmemory.dll";
            var asm = System.Reflection.Assembly.UnsafeLoadFrom(location);
            vars.Logt("soulmemory.dll","loaded");
            
            vars.err = "Can't create instance of SoulMemory.EldenRing.EldenRing";
            dynamic instance = asm.CreateInstance("SoulMemory.EldenRing.EldenRing");
            vars.ER = instance;
            vars.Logt("SoulMemory.EldenRing.EldenRing", "instance created");

            vars.err = "Can't get SoulMemory.EldenRing.Boss";
            var bosses = asm.GetType("SoulMemory.EldenRing.Boss"); // enum of bosses


            vars.err = "Can't read EldenRing memory";
            vars.bossNames = new Dictionary<uint,string>();
            // vars.bossStates = new Dictionary<uint,bool>();
            vars.ER.TryRefresh();


            vars.err = "Can't enumerate bosses";
            foreach (var boss in Enum.GetValues(bosses))
            {
                if (boss !=null)
                {
                    dynamic attr = boss.GetType().GetMember(boss.ToString()).FirstOrDefault().GetCustomAttributes().FirstOrDefault();
                    vars.bossNames[(uint)boss] = attr.Name;
                    // vars.bossStates[(uint)boss]= vars.ER.ReadEventFlag((uint)boss);
                }
            }
            vars.ResetBosses();
            vars.Log("Bosses enumerated"); 
            
        }
        catch
        {
            vars.ER = null;
            return false;
        }
        return true;
    });
    // vars.ItemFromLookupTable = (Func<UInt32,UInt32,object>)((Category,ItemID) =>
    // {
    //     if (vars.ER == null)
    //         return null;
    //     var ItemClass = vars.ER.GetType().Assembly.GetType("SoulMemory.EldenRing.Item");
    //     var FromLookupTable = ItemClass.GetMethod("FromLookupTable");
    //     var CategoryClass = vars.ER.GetType().Assembly.GetType("SoulMemory.EldenRing.Category");

    //     var category = Enum.ToObject(CategoryClass, Category);
    //     var itm = FromLookupTable.Invoke(null, new object[]{category,ItemID});
    //     return itm;
    // });
    #endregion

    #region Reset/init controls

    vars.Reset = (Action<bool>)((keepValues)=>{
        if (vars.ER!=null)
        {
            vars.ResetBosses();
        }
        vars.LastBattleWon = false;
        vars.IsPlayerLoaded = false;
        // conditional operator doesn't work for ssome reason, I had to do an if else statment
        if (keepValues)
        {
            vars.SetNumOfGreatRunes(null);
            vars.DisplayDeathCounter(null);
            vars.PrevBossTime(null); // updated after each boss fight
            vars.CreateSeparator(false);
            vars.PreviousKillTime(null); // updated at the end of a winnig boss battle
            vars.PrevBossName(null);
        }
        else
        {
            vars.SetNumOfGreatRunes(0);
            vars.DisplayDeathCounter(0);
            vars.PrevBossTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero); // updated after each boss fight
            vars.CreateSeparator(false);
            vars.PreviousKillTime(TimeSpan.Zero); // updated at the end of a winnig boss battle
            vars.PrevBossName(" ");
        }
    });
    vars.Reset(true);
    vars.Startup = true; // don't set boss name at first startup
    #endregion
}

init
{
    vars.Logt("Init","");
    var module = modules.FirstOrDefault(m => m.ModuleName.ToLower() == "eldenring.exe");
    var scanner = new SignatureScanner(game, module.BaseAddress, module.ModuleMemorySize);
    var codeLocation = scanner.Scan(vars.sigScanTarget);
    vars.Logt("pattern found", codeLocation.ToString("X"));
    	
    var pointer = vars.ReadOffset(game,codeLocation,4,0);
    vars.Logt("pointer", pointer.ToString("X"));

    var GameDataMan = vars.ReadPointer(game,pointer);
    vars.GameDataMan = GameDataMan;
    vars.Logt("GameDataMan", GameDataMan.ToString("X"));
    
    vars.IsBossFight = new MemoryWatcher<byte>(GameDataMan+0xC0);
    vars.Logt("isBossFight", vars.IsBossFight.Current.ToString());

    vars.deathCount = new MemoryWatcher<int>(GameDataMan+0x94);
    vars.deathCount.Update(game);
    vars.DisplayDeathCounter(vars.deathCount.Current);
    vars.Logt("death count", vars.deathCount.Current.ToString());



    if (!vars.LoadSoulMem())
    {
        vars.Msgb(vars.err);
        vars.Log(vars.err);

    }        

}

update
{
    if (vars.ER == null ) 
    {
        return;
    }


    #region update soulmemory reading
    vars.ER.TryRefresh();

    var isPlayerLoadedOld = vars.IsPlayerLoaded;
    vars.IsPlayerLoaded= vars.ER.IsPlayerLoaded();
    if (!vars.IsPlayerLoaded)
    {
        if (isPlayerLoadedOld)
        {
            vars.Logt("Player","Logged out");
        }
        return;
    } else if (!isPlayerLoadedOld)
    {
        vars.Logt("Player","Logged in");
    }


    #region update bosses' state
    var defeated = new List<uint>();
    foreach (var boss in vars.RemainingBoss)
    {
        var currentState = vars.ER.ReadEventFlag(boss);
        if (currentState)
        {
            if (!vars.Startup)
            {
                vars.PrevBossName(vars.bossNames[boss]); // don't set boss name at first startup
            }
            vars.LastBattleWon = true;
            defeated.Add(boss);
        }
    }
    foreach(var boss in defeated)
    {
        vars.RemainingBoss.Remove(boss);
    }

    if (defeated.Count > 0)
    {
        foreach(var boss in vars.RemainingBoss)
        {
            vars.Logt("RemainingBoss", vars.bossNames[boss]);
        }
    }
    #endregion

    
    #region update inventory

    var inventory = new List<UInt32>();
    var KeyItemInvData = new int[]{ 0x5D0, 1, 384}; // offset,isKey,length

    var playerGameData = vars.ReadPointer(game,vars.GameDataMan + 0x8 );
    var equipInventoryData = vars.ReadPointer(game,playerGameData + KeyItemInvData[0]);

    var inventoryList = vars.ReadPointer(game,equipInventoryData + 0x10 + 0x10*KeyItemInvData[1] );
    var inventoryNum = vars.ReadInt(game,equipInventoryData + 0x18);

    int count = 0;
    for (int i = 0;i<KeyItemInvData[2];i++)
    {
        var itemStruct = inventoryList + (i *0X18);
        var GaItemHandle = vars.ReadInt(game,itemStruct);
        var itemID =(UInt32) vars.ReadInt(game,itemStruct + 4);
        var itemType = itemID & 0xF0000000;
        itemID = itemID & ~itemType;

        var quantity = vars.ReadInt(game,itemStruct+8);

        if (itemID <= 0x5FFFFFFF 
        && itemID != 0
        && quantity!= 0 
        && itemID != 0xFFFFFFFF 
        && GaItemHandle !=0)
        {
            inventory.Add(itemID);
            count++;
        }

        if (count> inventoryNum)
        {
            break;
        }

    }

    #region Read great runes 
    const int GODRICK_S_GREAT_RUNE = 191;
    const int GODRICK_S_GREAT_RUNE_UNPOWERED = 8148;

    const int RADAHN_S_GREAT_RUNE = 192;
    const int RADAHN_S_GREAT_RUNE_UNPOWERED = 8149;

    const int MORGOTT_S_GREAT_RUNE = 193; 
    const int MORGOTT_S_GREAT_RUNE_UNPOWERED = 8150;

    const int RYKARD_S_GREAT_RUNE = 194; 
    const int RYKARD_S_GREAT_RUNE_UNPOWERED = 8151;
    
    const int MOHG_S_GREAT_RUNE = 195; 
    const int MOHG_S_GREAT_RUNE_UNPOWERED = 8152;

    const int MALENIA_S_GREAT_RUNE = 196;
    const int MALENIA_S_GREAT_RUNE_UNPOWERED = 8153;

    const int GREAT_RUNE_OF_THE_UNBORN = 10080;
    

    int[,] gt =
    {
        {GODRICK_S_GREAT_RUNE,GODRICK_S_GREAT_RUNE_UNPOWERED },
        {RADAHN_S_GREAT_RUNE,RADAHN_S_GREAT_RUNE_UNPOWERED },
        {MORGOTT_S_GREAT_RUNE,MORGOTT_S_GREAT_RUNE_UNPOWERED },
        {RYKARD_S_GREAT_RUNE,RYKARD_S_GREAT_RUNE_UNPOWERED },
        {MOHG_S_GREAT_RUNE,MOHG_S_GREAT_RUNE_UNPOWERED },
        {MALENIA_S_GREAT_RUNE,MALENIA_S_GREAT_RUNE_UNPOWERED },
        {GREAT_RUNE_OF_THE_UNBORN,GREAT_RUNE_OF_THE_UNBORN }
    };

    int numberOfGreateRunes = 0;

    foreach (var item in inventory)
    {
        for (int i = 0;i < gt.GetLength(0);i++)
        {
            if (item== gt[i,0] || item == (gt[i,1]))
            {
                numberOfGreateRunes++;
            }
        }
    }
    vars.SetNumOfGreatRunes(numberOfGreateRunes);

    #endregion
    #endregion
    #endregion

    #region update death count and timer

    if (vars.IsPlayerLoaded)
    {
        vars.deathCount.Update(game);
        if (vars.deathCount.Current != vars.deathCount.Old)
        {	
            vars.Logt("death count", vars.deathCount.Current.ToString());
            vars.DisplayDeathCounter(vars.deathCount.Current);
        }	
    }
    vars.IsBossFight.Update(game);
    vars.ShouldReset = (vars.IsBossFight.Old == 0 && vars.IsBossFight.Current == 1);
    #endregion

    vars.Startup = false;
}

onReset
{
    if (!vars.ShouldReset) // means that it was reset manually
    {
        vars.Reset(false); // reset every displayed information
        vars.Logt("Manual reset", "Done");
    }
    vars.ShouldReset = false;
}
reset
{
    var shouldReset = vars.ShouldReset; // resets the timer when a new boss fight begins
	
	if (shouldReset)
    {
		vars.Logt("timer","reset");
        vars.PrevBossTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
    }
    return shouldReset;
}


start
{
	if (vars.IsBossFight.Current == 1)
	{
        vars.Logt("timer","started");
		return true; // start timer during boss fight (called only when timer is reset)
	}
}

isLoading
{
	if (vars.IsBossFight.Current == 0)
	{
        if (vars.LastBattleWon)
        {
            vars.PreviousKillTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
            vars.LastBattleWon = false;
        }
        if (vars.IsBossFight.Old == 1)
        {
		    vars.Logt("timer","paused");
        }
		return true;
	}
}


