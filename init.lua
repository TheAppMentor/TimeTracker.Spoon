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

allTasks = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/allTasks.json")
selectedTask = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/selectedTask.json")
timeLog = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json")

prashMenuBar = hs.menubar.new()

function getCurrentActiveTask() 
    local selectedBoy = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/selectedTask.json")
    local currentTaskName = selectedBoy["title"] 
    return currentTaskName
end


function fetchActiveTask() 
    timeLog = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json")
    if timelog == nil or #timelog == 0 then 
        return
    end
    return timeLog[#timeLog] --Fetch the last task from the time log 
end

function createBlankTask()
    -- create dummy task from template 
    local dummyTask = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/timeLogTemplate.json")
    local currTaskName = getCurrentActiveTask()

    dummyTask["title"] = currTaskName 
    dummyTask["startTime"] = hs.timer.secondsSinceEpoch()

    -- Write the task to JSON
    table.insert(timeLog, dummyTask)
    hs.json.write(timeLog, "~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json",true,true)
end

prashMenuBar = hs.menubar.new()

--TIMER_DURATION = 25 * 60 --25 Minutes
TIMER_DURATION = 15 --25 Secs for Testing 
TOTAL_INTERVAL_COUNT = 5  -- 3 Secs for Testing
TIMER_INTERVAL_SECS = TIMER_DURATION / TOTAL_INTERVAL_COUNT 

function updateTimer() 

    -- Here we calcuate the time elapsed and set the bars accordingly in the menu bar.
    --local entireTable = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json")
    --local currentTask = entireTable[#entireTable]

    local currentTask = fetchActiveTask() 

    local startTime = currentTask["startTime"] 
   
    -- read the start time from the file. If elapsed time is > 5 mins, update one of the bars.
    local elapsedTime = hs.timer.secondsSinceEpoch() - startTime
  
    local intervalElapsed = math.floor(elapsedTime/TOTAL_INTERVAL_COUNT)
    local intervalPending = math.floor(TOTAL_INTERVAL_COUNT- intervalElapsed)

    local doneString = ""
    local pendingString = ""

    for i=1,intervalElapsed do 
        doneString = doneString .. "▐"
    end
    
    for i=1,intervalPending do 
        pendingString = pendingString .. "▐"
    end

    local styledText1 = hs.styledtext.new(doneString,{font = {size = 16 }, color = hs.drawing.color.colorsFor("Crayons").Lime})
    local styledText2 = hs.styledtext.new(pendingString,{font = {size = 16 }, color = hs.drawing.color.colorsFor("Crayons").Steel})
    local styledBoy = styledText1 .. styledText2

    prashMenuBar:setTitle(styledBoy)

    if elapsedTime >= TIMER_DURATION then
        wrapUpActiveTask()
    end
end

-- Global Timer Object
globalTimer = nil 

function startActiveTask() 
    timerState = IS_RUNNING;
    -- create a blank task with currently selected task.
    createBlankTask()
    buildMainMenu()
    globalTimer = hs.timer.doEvery(TIMER_INTERVAL_SECS, updateTimer) 
end

function stopActiveTask() 
    timerState = IS_STOPPED;

    --local entireTable = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json")
    -- local currentTask = entireTable[#entireTable]
    local currentTask = fetchActiveTask() 
    currentTask["stopTime"] = hs.timer.secondsSinceEpoch()


    updateActiveTask(currentTask)
    -- Write the task to JSON
    --timeLog[#timeLog] = currentTask 
    --hs.json.write(timeLog, "~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json",true,true)

    buildMainMenu()
end

function pauseActiveTask() 
    timerState = IS_PAUSED;

    local currentTask = fetchActiveTask()
    --local entireTable = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json")
    --local currentTask = entireTable[#entireTable]

    -- fetch pauses inside current task
    local pauses = currentTask.pauses
    --table.insert(pauses, {"pauseStart"})
    local pauseStartTime = hs.timer.secondsSinceEpoch()

    local pauseReason = promptForUserInput("Paused","Enter Pause Reason")

    table.insert(pauses, {startTime = pauseStartTime, endTime = "" , pauseReason = pauseReason}) 
    currentTask.pauses = pauses

    -- Update the last task in the list 
    updateActiveTask(currentTask)

    tempActiveTask["pauses"] = pauses 
end


function resumePausedTask() 
    timerState = IS_RUNNING;

    --local entireTable = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json")
    --local currentTask = entireTable[#entireTable]
    local currentTask = fetchActiveTask()

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
    --timeLog[#timeLog] = currentTask 
    --hs.json.write(timeLog, "~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json",true,true)

    --tempActiveTask["pauses"] = pauses 
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
    if timerState == IS_PAUSED then
        abandonPausedTask()
        return
    end

    timerState = IS_STOPPED;

    --local entireTable = hs.json.read("~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json")
    --local currentTask = entireTable[#entireTable]
    
    local currentTask = fetchActiveTask()
    currentTask.endTime = hs.timer.secondsSinceEpoch()

    local userInput = promptForUserInput("Task Complete", "Enter Notes")
    currentTask.notes = "Task End : " .. userInput  

    updateActiveTask(currentTask)
    
    globalTimer:stop() 
    initializeMenuBar()

    buildMainMenu()
end

function abandonPausedTask() 

end

function abandonActiveTask() 
    timerState = IS_STOPPED;

    currentTask = fetchActiveTask()
    currentTask["wasAbandoned"] = true 
    currentTask.endTime = nil 
    currentTask.timeAbandonded = hs.timer.secondsSinceEpoch()

    local abandonReason = promptForUserInput("Task Abandoned", "Enter Reason")
    currentTask.abandonReason = abandonReason 

    -- Update the last task in the list 
    -- timeLog[#timeLog] = currentTask 
    -- hs.json.write(timeLog, "~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json",true,true)
    updateActiveTask(currentTask)

    globalTimer:stop() 
    buildMainMenu()
end

function updateActiveTask(updatedTask)
    -- Update the last task in the list 
    timeLog[#timeLog] = updatedTask 
    hs.json.write(timeLog, "~/.hammerspoon/Spoons/TimeTracker.spoon/timeLog.json",true,true)
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
    hs.json.write({title = selectedTask}, "~/.hammerspoon/Spoons/TimeTracker.spoon/selectedTask.json",true,true)
    buildMainMenu()
end

function buildTaskListMenu(selectedTaskName) 
    local subMenu = {}

    for i,task in ipairs(allTasks) do
        local taskTitle = task["title"]
        --local isSelected = taskTitle == selectedTask["title"]
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
    local initalString = hs.styledtext.new("▐▐▐▐▐",{font = {size = 16 }, color = hs.drawing.color.colorsFor("Crayons").Steel})
    prashMenuBar:setTitle(initalString)
end

initializeMenuBar()
prashMenuBar:setClickCallback(calledFunction)
prashMenuBar:setMenu(buildMainMenu) 

return obj

-- Features to implement
    -- Bug: Task Selection is not working. 
    -- When a task is stopped or abandoned. We should prompt for reason text .. 
    -- When a pause exceeds the task duration (30 mins) we should mark the task as abandoned.
        -- Work on the visual bar indicator - for paused, start and stopped state.
        -- 
        -- If PAUSE execceds the task durartion. Automatically abandon the task.

        -- Put the device automiatcialy in DND when a task is running.
-- To Enable and disable DO NOT Disturb
-- https://github.com/derekwyatt/dotfiles/blob/c382fa9e83722c11aa89d124b658862935633645/hammerspoon-init.lua#L278
-- Instead of wasAbandoned. Have a states, ABANDONED. COMPLETED. PAUSE_ABANDONED. IN_RUNNING
