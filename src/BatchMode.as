
string g_batchModeText = "";

void BatchModeInterface()
{
    UI::TextWrapped(
        "To create replays in batch, input Map Uid and Ghost WebServices Id separated by semi-colon (;). For example:\n"
        "\n"
        "DG0d5RcL2wYeRfM44qokhvvrH00; c758570f-b8bc-4300-9d79-1b583f1b25b1\n"
        "x3yEC7QjBZdvROEt0tmDe0KzMqf; 354ca171-eb4c-4d75-a1db-cc62477986e5\n"
        "ZnnV55ZvskhuU2fO7m1Dkw4Ofu6; 9e3231b5-97de-45bf-8cfa-ff05f0abd900\n"
        "\n"
        "Watch the Openplanet log for progress during batch execution."
    );
    UI::Dummy(vec2(10, 10));
    UI::BeginDisabled(triggerDownload);
    g_batchModeText = UI::InputTextMultiline("##batchModeInput", g_batchModeText, vec2(500, 200));
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

    string replayName = GetReplayFilename(gst, map);
    string replayPath = "Downloaded/" + replayName;
    print("Creating replay at " + replayPath + ".Replay.Gbx");
    cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr.Replay_Save(replayPath, map, gst);
}

CGameCtnChallenge@ DownloadMap(const string&in uid)
{
    if (IO::FileExists(IO::FromUserGameFolder("Maps/Downloaded/GhostToReplayBatch/" + uid + ".Map.Gbx")))
    {
        print("Map already exists, skipping download. Delete Maps/Downloaded/GhostToReplayBatch to force re-download if desired");
    }
    else
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
            if (!IO::FolderExists(path))
            {
                IO::CreateFolder(path);
                Fids::UpdateTree(Fids::GetUserFolder("Maps/Downloaded"));
                yield();
            }
            string filePath = path + "/" + uid + ".Map.Gbx";
            print("Saving to " + filePath);
            response.SaveToFile(filePath);
        }
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
    string baseUrl = "https://prod.trackmania.core.nadeo.online/mapRecords/";
    string tailUrl = "/replay";
    string url = baseUrl + ghostId + tailUrl;
    if (Setting_BatchModeGhostUrlNoise)
    {
        string noiseFragment = Crypto::RandomBase64(12, url: true);
        url += "#" + noiseFragment;
    }

    print("Using URL for ghost: " + url);
    auto@ menuCustom = cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp;
    auto@ task = menuCustom.DataFileMgr.Ghost_Download("", url);

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

