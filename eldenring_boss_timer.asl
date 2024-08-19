state("eldenring")
{
}

startup
{
    vars.shouldReset = false;

    Console.Clear();
    Console.WriteLine(DateTime.Now.ToString());

    #region log

    vars.msgb = (Action<String>)((text) =>
    {
        MessageBox.Show(text,"SoulMemScript",MessageBoxButtons.OK,MessageBoxIcon.Information);
    });

    vars.log = (Action<String>) ((text) =>
    {
        print(String.Format("[ER boss timer] {0}",text));
        Console.WriteLine(String.Format("[ER boss timer] {0}",text));
    });
    vars.logt = (Action<String,String>)((title,text)=>
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
                            vars.logt("control found", controlName);
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
                vars.logt("control created", controlName);
            }
            if (!timer.Layout.LayoutComponents.Contains(control))
            {
                vars.logt("control added", controlName);
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
                    vars.logt("Sperator", "Existing");
                    found = true;
                    break;
                }
        }
        if (ignoreExistant || !found)
        {
            var compo = new LiveSplit.UI.Components.LayoutComponent("",new LiveSplit.UI.Components.SeparatorComponent());
            timer.Layout.LayoutComponents.Add(compo);
            vars.logt("Separator","Created");
        }
    });
    #endregion

    #region Update textboxes

    vars.setText = (Action<String,String>)((Value1,Value2)=>
    {
        dynamic component = vars.GetControl(Value1).Component;
        component.Settings.Text1 = Value1;
        component.Settings.Text2 = Value2;    
    });


    
    vars.prevBossTime = (Action<TimeSpan>)((time)=>
    {
        vars.setText("Previous fight time",new DateTime(time.Ticks).ToString("HH:mm:ss.ff"));
    });


    vars.displayDeathCounter = (Action<int>)((counter) =>
    {
        vars.setText("Death counter",counter.ToString());

    });

    vars.PreviousKillTime = (Action<TimeSpan>)((time)=>
    {
        vars.setText("Previous boss time",new DateTime(time.Ticks).ToString("HH:mm:ss.ff"));
    });

    vars.prevBossName = (Action<String>)((name)=>
    {
        vars.setText("=",name);
    });

    vars.setNumOfGreatRunes = (Action<int>)((number)=>
    {
        vars.setText("Great runes",number.ToString());
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

    vars.loadSoulMem = (Func<bool>)(()=> 
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
            
            vars.logt("soulmemory.dll", "found");

            vars.err = "Can't load soulmemory.dll";
            var asm = System.Reflection.Assembly.UnsafeLoadFrom(location);
            vars.logt("soulmemory.dll","loaded");
            
            vars.err = "Can't create instance of SoulMemory.EldenRing.EldenRing";
            dynamic instance = asm.CreateInstance("SoulMemory.EldenRing.EldenRing");
            vars.ER = instance;
            vars.logt("SoulMemory.EldenRing.EldenRing", "instance created");

            vars.err = "Can't get SoulMemory.EldenRing.Boss";
            var bosses = asm.GetType("SoulMemory.EldenRing.Boss"); // enum of bosses


            vars.err = "Can't read EldenRing memory";
            vars.bossNames = new Dictionary<uint,string>();
            vars.bossStates = new Dictionary<uint,bool>();
            vars.ER.TryRefresh();

            foreach (var boss in Enum.GetValues(bosses))
            {
                if (boss !=null)
                {
                    dynamic attr = boss.GetType().GetMember(boss.ToString()).FirstOrDefault().GetCustomAttributes().FirstOrDefault();
                    vars.bossNames[(uint)boss] = attr.Name;
                    vars.bossStates[(uint)boss]= vars.ER.ReadEventFlag((uint)boss);
                }
            }
            vars.log("Bosses enumerated"); 
            
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

    #region init controls
    vars.lastBattleWon = false;
    vars.isPlayerLoaded = false;
    vars.setNumOfGreatRunes(0);
    vars.displayDeathCounter(0);
    vars.prevBossTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero); // updated after each boss fight
    vars.CreateSeparator(false);
    vars.PreviousKillTime(TimeSpan.Zero); // updated at the end of a winnig boss battle
    vars.prevBossName(" ");
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
    vars.GameDataMan = GameDataMan;
    vars.logt("GameDataMan", GameDataMan.ToString("X"));
    
    vars.isBossFight = new MemoryWatcher<byte>(GameDataMan+0xC0);
    vars.logt("isBossFight", vars.isBossFight.Current.ToString());

    vars.deathCount = new MemoryWatcher<int>(GameDataMan+0x94);
    vars.deathCount.Update(game);
    vars.displayDeathCounter(vars.deathCount.Current);
    vars.logt("death count", vars.deathCount.Current.ToString());



    if (!vars.loadSoulMem())
    {
        vars.msgb(vars.err);
        vars.log(vars.err);

    }        

}

update
{
    #region update death count and timer
    vars.deathCount.Update(game);
	if (vars.deathCount.Current != vars.deathCount.Old)
	{	
        vars.logt("death count", vars.deathCount.Current.ToString());
        vars.displayDeathCounter(vars.deathCount.Current);
	}	
    
	vars.isBossFight.Update(game);
    vars.shouldReset = (vars.isBossFight.Old == 0 && vars.isBossFight.Current == 1);
    #endregion

    #region update soulmemory reading
    if (vars.ER == null ) 
    {
        return;
    }

    vars.ER.TryRefresh();

    var isPlayerLoadedOld = vars.isPlayerLoaded;
    vars.isPlayerLoaded= vars.ER.IsPlayerLoaded();
    if (!vars.isPlayerLoaded)
    {
        if (isPlayerLoadedOld)
        {
            vars.logt("Player","Logged out");
        }
        return;
    } else if (!isPlayerLoadedOld)
    {
        vars.logt("Player","Logged in");
    }


    #region update bosses' state
    foreach(var kvp in vars.bossStates)
    {
        var currentState = vars.ER.ReadEventFlag(kvp.Key);
        if (currentState!=kvp.Value)
        {
            vars.bossStates[kvp.Key] = currentState;
            vars.prevBossName(vars.bossNames[kvp.Key]);
            vars.lastBattleWon = true;
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

    #region Read great runes // Not working
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
    vars.setNumOfGreatRunes(numberOfGreateRunes);

    #endregion
    #endregion
    #endregion
}

reset
{
    var shouldReset = vars.shouldReset; // resets the timer when a new boss fight begins
    vars.shouldReset = false;
	
	if (shouldReset)
    {
		vars.logt("timer","reset");
        vars.prevBossTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
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
        if (vars.lastBattleWon)
        {
            vars.PreviousKillTime(timer.CurrentTime.GameTime ?? TimeSpan.Zero);
            vars.lastBattleWon = false;
        }
        if (vars.isBossFight.Old == 1)
        {
		    vars.logt("timer","paused");
        }
		return true;
	}
}


