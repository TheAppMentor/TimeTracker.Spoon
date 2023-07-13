-- 12-July Timer is running over.. i.e 25 mins timer runs for 30 mins.
-- 12-July Make the webview to show the Summary of tasks https://github.com/asmagill/hammerspoon-config/blob/432c65705203d7743d3298441bd4319137b466fd/_scratch/webviewOtherURLS.lua#L48 
--
--
local obj={}

-- Metadata
obj.name = "TimeTracker"
obj.version = "1.0"
obj.author = "prashanth <prashanth.moorthy@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Global Vars
IS_STOPPED = 0 
IS_RUNNING = 1
IS_PAUSED = 2 

DISALBED = true
ENABLED = false 

-- Value holding state
timerState = IS_STOPPED -- initally in stopped state

-- Files
pathToAllTasksFile = "~/.hammerspoon/Spoons/TimeTracker.spoon/allTasks.json"
pathToSelectedTaskFile = "~/.hammerspoon/Spoons/TimeTracker.spoon/selectedTask.json"
pathToTimeLogFile = "~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json"

-- Global Timer 
globalTimer = nil 

-- Global Color
yellow = hs.drawing.color.colorsFor("Crayons").Lemon
gray = hs.drawing.color.colorsFor("Crayons").Steel
green = hs.drawing.color.colorsFor("Crayons").Lime

local grayBar = {font = {size = 16 }, color = gray}
local greenBar = {font = {size = 16 }, color = green}
local yellowBar = {font = {size = 16 }, color = yellow}

prashMenuBar = hs.menubar.new()

TOTAL_TIMER_DURATION = 25 * 60       -- 25 Minutes
TOTAL_INTERVAL_COUNT = 5             -- Traslates to number of bars/ticks in UI
TIMER_INTERVAL_SECS = (TOTAL_TIMER_DURATION / TOTAL_INTERVAL_COUNT) 

function getCurrentActiveTask() 
    local selectedBoy = hs.json.read(pathToSelectedTaskFile)
    local currentTaskName = selectedBoy["title"] 
    return currentTaskName
end

function fetchActiveTask() 
    local timeLog = hs.json.read(pathToTimeLogFile)
    return timeLog[#timeLog] --Fetch the last task from the time log 
end

function createBlankTask()
    local currTaskName = getCurrentActiveTask()
    local dummyTask = {}
    dummyTask.title = currTaskName 
    dummyTask.startTime = hs.timer.secondsSinceEpoch()
    dummyTask.status = "RUNNING" 
    dummyTask.pauses = {} 

    -- Write the task to JSON
    local timeLog = hs.json.read(pathToTimeLogFile)
    table.insert(timeLog, dummyTask)
    hs.json.write(timeLog, pathToTimeLogFile, true,true)
end

function updateTimer() 
    -- Here we calcuate the time elapsed and set the bars accordingly in the menu bar.
    local currentTask = fetchActiveTask() 
    local startTime = currentTask["startTime"] 
   
    -- read the start time from the file. If elapsed time is > 5 mins, update one of the bars.
    local elapsedTime = hs.timer.secondsSinceEpoch() - startTime
    local isTaskComplete = elapsedTime >= TOTAL_TIMER_DURATION
  
    local intervalElapsed = math.floor(elapsedTime / TIMER_INTERVAL_SECS)
    local intervalPending = math.floor(TOTAL_INTERVAL_COUNT - intervalElapsed)

    local doneString = ""
    local pendingString = ""

    -- https://www.luascript.dev/blog/luas-missing-ternary-operator
    -- when and is true, the first argument is returned. When or is true, the second argument is used.
    local inProcessStringLength = isTaskComplete == true and 0 or 1 
    
    for i=1,intervalElapsed do 
        doneString = doneString .. "▐"
    end

    for i=1,intervalPending - inProcessStringLength do 
        pendingString = pendingString .. "▐"
    end

    local styledInProcessString = hs.styledtext.new("▐", yellowBar)
    local styledPendingString = hs.styledtext.new(pendingString, grayBar)
    local styledDoneString = hs.styledtext.new(doneString, greenBar)

    local styledBoy = styledDoneString .. styledInProcessString .. styledPendingString 
    -- Just got lazy here.. could not think of a logic to make the last bar green when a task completes
    if inProcessStringLength == 0 then
        styledBoy = styledDoneString .. styledPendingString 
    end
    prashMenuBar:setTitle(styledBoy)

    if isTaskComplete then
        wrapUpActiveTask()
    end
end

function startActiveTask() 
    timerState = IS_RUNNING;
    -- create a blank task with currently selected task.
    createBlankTask()
    buildMainMenu()

    local firstSegmentProcessing = hs.styledtext.new("▐", yellowBar)
    local remainingSegmentPending = hs.styledtext.new("▐▐▐▐", grayBar)

    prashMenuBar:setTitle(firstSegmentProcessing .. remainingSegmentPending)

    globalTimer = hs.timer.doEvery(TIMER_INTERVAL_SECS, updateTimer) 
end

function pauseActiveTask() 
    timerState = IS_PAUSED;

    local currentTask = fetchActiveTask()
    currentTask.status = "PAUSED"

    -- fetch pauses inside current task
    local pauses = currentTask.pauses
    local pauseStartTime = hs.timer.secondsSinceEpoch()

    local pauseReason = promptForUserInput("Paused","Enter Pause Reason")

    table.insert(pauses, {startTime = pauseStartTime, endTime = "" , pauseReason = pauseReason}) 
    currentTask.pauses = pauses

    -- Update the last task in the list 
    updateActiveTask(currentTask)

    --tempActiveTask["pauses"] = pauses 
end

function resumePausedTask() 
    timerState = IS_RUNNING;

    local currentTask = fetchActiveTask()
    currentTask.status = "RUNNING"
    -- fetch pauses inside current task
    local pauses = currentTask.pauses
    --table.insert(pauses, {"pauseStart"})

    local lastPause = pauses[#pauses]
    lastPause.endTime = hs.timer.secondsSinceEpoch()
    pauses[#pauses] = lastPause
    --table.insert(pauses, {startTime = hs.timer.secondsSinceEpoch(), endTime = hs.timer.secondsSinceEpoch() }) 

    currentTask.pauses = pauses

    -- Update the last task in the list 
    updateActiveTask(currentTask)
end

function togglePauseState() 
    if timerState == IS_RUNNING then
        pauseActiveTask()
        return
    elseif timerState == IS_PAUSED then
        resumePausedTask()
    end
end

function promptForUserInput(title,subTitle) 
    local lastApplication = hs.application.frontmostApplication()
    hs.application.get("Hammerspoon"):activate()
    local selectedButton, userInput = hs.dialog.textPrompt(title, subTitle, "", "OK", "Cancel")
    if lastApplication then
        lastApplication:activate()
    end
    return userInput
end

function wrapUpActiveTask() 

    local currentTask = fetchActiveTask()
    local promptHeading = "Task Complete" 

    if timerState == IS_PAUSED then
        currentTask.status = "PAUSE ABANDONED"
        promptHeading = "Task Abandoned"
    elseif timerState == IS_RUNNING then
        currentTask.status = "COMPLETED"
    end

    timerState = IS_STOPPED;
    currentTask.endTime = hs.timer.secondsSinceEpoch()

    local userInput = promptForUserInput(promptHeading, "Enter Notes")
    currentTask.notes = "Task End : " .. userInput  

    updateActiveTask(currentTask)
    
    globalTimer:stop() 
    initializeMenuBar()

    buildMainMenu()
end

function abandonPausedTask() 
    local currentTask = fetchActiveTask()
    currentTask.status = "PAUSE ABANDONED"
    currentTask.endTime = hs.timer.secondsSinceEpoch()
end

function abandonActiveTask() 
    timerState = IS_STOPPED;

    currentTask = fetchActiveTask()
    currentTask.status = "ABANDONED" 
    currentTask.endTime = nil 
    currentTask.timeAbandonded = hs.timer.secondsSinceEpoch()

    local abandonReason = promptForUserInput("Task Abandoned", "Enter Reason")
    currentTask.abandonReason = abandonReason 

    updateActiveTask(currentTask)

    globalTimer:stop() 
    buildMainMenu()
end

function updateActiveTask(updatedTask)
    -- Update the last task in the list 
    local timeLog = hs.json.read(pathToTimeLogFile)
    timeLog[#timeLog] = updatedTask 
    hs.json.write(timeLog, pathToTimeLogFile, true,true)
end

function obj:init()
    hs.console.clearConsole()
    fetchActiveTask()
    buildMainMenu()
end

function getStopButtonState()
    --hs.dialog.textPrompt("Main message.", timerState, "", "OK", "Cancel", true)
    if timerState == IS_RUNNING then 
        return ENABLED 
    end  
    
    if timerState == IS_STOPPED then 
        return DISALBED 
    end  
    
    if timerState == IS_PAUSED then 
        return DISALBED 
    end  

    return DISALBED
end

function getPauseButtonState()
    if timerState == IS_STOPPED then 
        return DISALBED 
    end 
    
    return ENABLED 
end

function getResetButtonState()
    if timerState == IS_STOPPED then 
        return DISALBED 
    end 
    return ENABLED 
end

function getStartButtonState()
    if timerState == IS_STOPPED then 
        return ENABLED 
    end 
    
    return DISALBED
end

function setCurrentTask(selectedTask)
    hs.json.write({title = selectedTask}, pathToSelectedTaskFile, true,true)
    buildMainMenu()
end

function buildTaskListMenu(selectedTaskName) 
    local subMenu = {}

    -- fetchAllTasks
    local allTasks = hs.json.read(pathToAllTasksFile)

    for i,task in ipairs(allTasks) do
        local taskTitle = task["title"]
        local isSelected = taskTitle == selectedTaskName 
        table.insert(subMenu, {title = taskTitle, checked = isSelected, fn = function() setCurrentTask(taskTitle) end })
    end

    return subMenu 
end
function buildMainMenu() 
    
    local currentTaskName = getCurrentActiveTask()

    local taskSubMenu = {}
    if timerState == IS_STOPPED then
        taskSubMenu = buildTaskListMenu(currentTaskName)
    end

    local startButtonState = getStartButtonState() 
    local stopButtonState = getStopButtonState()
    local resetButtonState = getResetButtonState() 

    local pauseButtonState = getPauseButtonState() 
    local pauseButtonTitle = "⏸️ Pause"

    if timerState == IS_PAUSED  then
        pauseButtonTitle =  "▶️ Resume" 
    end
    local menuTable = {} 

    table.insert(menuTable, { title = currentTaskName, menu = taskSubMenu })
    table.insert(menuTable, { title = "-" })
    table.insert(menuTable, { title = "▶️  Start", fn = function() startActiveTask() end, disabled = startButtonState})
    table.insert(menuTable, { title = pauseButtonTitle, fn = function() togglePauseState() end, disabled = pauseButtonState })
    table.insert(menuTable, { title = "🚮 Abandon", fn = function() abandonActiveTask() end, disabled = resetButtonState})

    return menuTable
end

function initializeMenuBar() 
    -- When we are Idle, we start with a everything diabled/gray color
    local initalString = hs.styledtext.new("▐▐▐▐▐", grayBar)
    prashMenuBar:setTitle(initalString)
end

initializeMenuBar()
prashMenuBar:setClickCallback(calledFunction)
prashMenuBar:setMenu(buildMainMenu) 

return obj

-- Features to implement
-- When a pause exceeds the task duration (30 mins) we should mark the task as abandoned.
-- To disable 
-- Put the device automiatcialy in DND when a task is running.
    -- To Enable and disable DO NOT Disturb
    -- https://github.com/derekwyatt/dotfiles/blob/c382fa9e83722c11aa89d124b658862935633645/hammerspoon-init.lua#L278
