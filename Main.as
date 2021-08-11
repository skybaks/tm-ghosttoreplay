
string name = "";
string inputUrl = "";
string savedMessage = "";
bool triggerDownload = false;
bool windowVisible = false;

void log(string msg)
{
    print("[\\$9cf" + name + "\\$fff] " + msg);
}

void RenderMenu()
{
    if (UI::MenuItem("\\$999" + Icons::Download + "\\$z Ghost to Replay", "", windowVisible) && !windowVisible)
    {
        windowVisible = !windowVisible;
    }
}

void RenderInterface()
{
    if (windowVisible)
    {
        UI::Begin("Ghost To Replay", windowVisible, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);

        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app.RootMap !is null)
        {
            UI::Text("Enter download URL for the Ghost");
            inputUrl = UI::InputText("Ghost URL", inputUrl);
            UI::Text("\\$f99WARNING:\\$ccc An invalid URL will result in the game crashing");
            if (!triggerDownload && UI::Button("Create Replay"))
            {
                triggerDownload = true;
            }
            if (savedMessage != "")
            {
                UI::Text(savedMessage);
            }
        }
        else
        {
            UI::Text("Play the track you want to combine the ghost with");
            savedMessage = "";
        }

        UI::End();
    }
}

CGameDataFileManagerScript@ TryGetDataFileMgr()
{
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app !is null)
    {
        CSmArenaRulesMode@ playgroundScript = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (playgroundScript !is null)
        {
            CGameDataFileManagerScript@ dataFileMgr = cast<CGameDataFileManagerScript>(playgroundScript.DataFileMgr);
            if (dataFileMgr !is null)
            {
                return dataFileMgr;
            }
        }
    }
    return null;
}

void Main()
{
    name = Meta::ExecutingPlugin().Name;
    log("Initializing");

    while (true)
    {
        if (triggerDownload)
        {
            log("Download triggered for " + inputUrl);
            savedMessage = "";
            auto dataFileMgr = TryGetDataFileMgr();
            CTrackMania@ app = cast<CTrackMania>(GetApp());
            if (dataFileMgr !is null && app.RootMap !is null && inputUrl != "")
            {
                CWebServicesTaskResult_GhostScript@ result = dataFileMgr.Ghost_Download("", inputUrl);
                inputUrl = "";
                uint timeout = 20000;
                uint currentTime = 0;
                while (result.Ghost is null && currentTime < timeout)
                {
                    currentTime += 100;
                    sleep(100);
                }
                CGameGhostScript@ ghost = cast<CGameGhostScript>(result.Ghost);
                if (ghost !is null)
                {
                    string safeMapName = StripFormatCodes(app.RootMap.MapName);
                    string safeUserName = ""; // ghost.Nickname;
                    string safeCurrTime = Regex::Replace(app.OSLocalDate, "[/ ]", "_");
                    string fmtGhostTime = Time::Format(ghost.Result.Time);
                    string replayName = safeMapName + "_" + safeUserName + "_" + safeCurrTime + "_(" + fmtGhostTime + ")";
                    string replayPath = "Downloaded/" + replayName;
                    savedMessage = "Saving replay to " + replayPath + ".Replay.Gbx";
                    log(savedMessage);
                    dataFileMgr.Replay_Save(replayPath, app.RootMap, ghost);
                }
                else
                {
                    log("Download Failed");
                }
            }
            else
            {
                log("Failed");
            }
            triggerDownload = false;
        }

        sleep(1000);
    }
}