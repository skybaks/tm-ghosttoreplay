
string g_batchModeText = "";

void BatchModeInterface()
{
    UI::BeginDisabled(triggerDownload);
    g_batchModeText = UI::InputTextMultiline("##batchModeInput", g_batchModeText);
    if (UI::Button("Execute"))
    {
        triggerDownload = true;
    }
    UI::EndDisabled();
}

void BatchModeExecute()
{
    string[] lines = g_batchModeText.Split("\n");
    for (uint i = 0; i < lines.Length; ++i)
    {
        string[] elements = lines[i].Split(";");
        if (elements.Length == 2)
        {
            CreateReplay(elements[0].Trim(), elements[1].Trim());
        }
    }
    g_batchModeText = "";
    print("Execute complete");
}

void CreateReplay(const string&in mapUid, const string&in ghostId)
{
    print("Downloading map = " + mapUid);
    auto@ map = DownloadMap(mapUid);
    print("Downloading ghost = " + ghostId);
    auto@ gst = DownloadGhost(ghostId);

    if (map is null)
    {
        error("Error map is null for " + mapUid);
        return;
    }

    if (gst is null)
    {
        error("Error ghost is null for " + ghostId);
        return;
    }

    string replayPath = "Downloaded/GhostToReplayBatch/" + mapUid + "_" + ghostId + ".Replay.Gbx";
    print("Creating replay at " + replayPath);
    cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr.Replay_Save(replayPath, map, gst);
}

CGameCtnChallenge@ DownloadMap(const string&in uid)
{
    auto@ menuCustom = cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp;
    auto@ task = menuCustom.DataFileMgr.Map_NadeoServices_GetFromUid(menuCustom.UserMgr.Users[0].Id, uid);
    while (task.IsProcessing)
    {
        yield();
    }

    if (!task.HasSucceeded)
    {
        error("Error getting map file url for " + uid);
        return null;
    }

    string url = task.Map.FileUrl;

    print("HTTP Get to " + url);
    auto@ response = Net::HttpGet(url);
    while (!response.Finished())
    {
        yield();
    }

    print("Returned code " + tostring(response.ResponseCode()));

    if (response.Error() == "")
    {
        string path = IO::FromUserGameFolder("Maps/Downloaded/GhostToReplayBatch");
        IO::CreateFolder(path);
        string filePath = path + "/" + uid + ".Map.Gbx";
        print("Saving to " + filePath);
        response.SaveToFile(filePath);
    }

    auto@ fidFolder = Fids::GetUserFolder("Maps/Downloaded/GhostToReplayBatch");
    Fids::UpdateTree(fidFolder, false);
    yield();
    auto@ fidFile = Fids::GetFidsFile(fidFolder, uid + ".Map.Gbx");
    if (fidFile is null) { error("Error map fid was null for " + uid); return null; }
    return cast<CGameCtnChallenge@>(Fids::Preload(fidFile));
}

CGameGhostScript@ DownloadGhost(const string&in ghostId)
{
    string baseUrl = "https://trackmania.io/api/download/ghost/";

    auto@ menuCustom = cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp;
    auto@ task = menuCustom.DataFileMgr.Ghost_Download("", baseUrl + ghostId);

    while (task.IsProcessing)
    {
        yield();
    }

    if (!task.HasSucceeded)
    {
        error("Error while downloading ghost for " + ghostId);
        return null;
    }

    return cast<CGameGhostScript@>(task.Ghost);
}

