local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- CONFIGURACIÓN PRINCIPAL
local nombreArma = "Double Barreled shotgun"
local limiteMunicion = 100
local tiempoCompraMantener = 0.6
local running = false
local autoCollectConnection = nil

-- INTERFAZ GRÁFICA
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AtmFarmGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 160, 0, 50)
toggleButton.Position = UDim2.new(0.5, -80, 0.1, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 20
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Text = "START"
toggleButton.Parent = screenGui

-- RECOLECCIÓN EN SEGUNDO PLANO
local function iniciarRecoleccionAutomatica()
    if autoCollectConnection then return end
    autoCollectConnection = RunService.Heartbeat:Connect(function()
        if not running then return end
        pcall(function()
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "Money" and obj:IsA("BasePart") then
                    local detector = obj:FindFirstChildOfClass("ClickDetector")
                    if detector and fireclickdetector then
                        fireclickdetector(detector)
                    end
                end
            end
        end)
    end)
end

local function detenerRecoleccionAutomatica()
    if autoCollectConnection then
        autoCollectConnection:Disconnect()
        autoCollectConnection = nil
    end
end

-- LECTURA DE MUNICIÓN EN RESERVA
local function obtenerCantidadMunicion()
    local values = player:FindFirstChild("Values")
    local municionFolder = values and values:FindFirstChild("Municion")
    local ammoValue = municionFolder and municionFolder:FindFirstChild(nombreArma)

    if ammoValue and ammoValue:IsA("ValueBase") then
        return ammoValue.Value
    end
    return 0
end

local function verificarMunicionAgotada()
    return obtenerCantidadMunicion() <= 0
end

-- BÚSQUEDA DEL OBJETO DE LA TIENDA
local function obtenerObjetoMunicionTienda()
    local tienda = workspace:FindFirstChild("TiendaArmas")
    if not tienda then return nil end

    for _, item in ipairs(tienda:GetChildren()) do
        local nameLower = item.Name:lower()
        if nameLower:find("double") or nameLower:find("shotgun") or nameLower:find("escopeta") or nameLower:find("municion") then
            return item
        end
    end

    return tienda:GetChildren()[46]
end

-- RUTINA DE COMPRA EN TIENDA
local function irAComprarMunicion()
    local objetoMunicion = obtenerObjetoMunicionTienda()
    if not objetoMunicion then return end

    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    rootPart.Anchored = false

    local targetPos = objetoMunicion:IsA("BasePart") and objetoMunicion.Position or objetoMunicion:GetPivot().Position
    
    rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 1))
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPos)
    
    task.wait(0.5)

    local prompt = objetoMunicion:FindFirstChildWhichIsA("ProximityPrompt", true)

    while running and obtenerCantidadMunicion() < limiteMunicion do
        camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPos)

        if prompt and fireproximityprompt then
            fireproximityprompt(prompt)
            task.wait(tiempoCompraMantener)
        else
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(tiempoCompraMantener)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end

        task.wait(0.15)
    end

    task.wait(0.3)
end

-- VALIDACIÓN DE OBJETOS ACTIVOS CON HUMANOID (ATM / CAJA)
local function objetivoEstaActivo(target)
    if not target or not target.Parent then return false end
    
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then
        return false
    end

    return true
end

-- OBTENER PARTE OBJETIVO DE ATM O CAJA REGISTRADORA
local function obtenerParteObjetivo(target)
    if not objetivoEstaActivo(target) then return nil end
    return target:FindFirstChild("MainScreen")
        or target:FindFirstChild("Pantalla") 
        or target:FindFirstChild("Register")
        or target:FindFirstChild("Part") 
        or target:FindFirstChildWhichIsA("BasePart")
end

-- CÁLCULO MEJORADO DE POSICIÓN FRONTAL AL ATM / CAJA
local function posicionarFrenteObjetivo(target, targetPart, rootPart)
    local cfTarget = targetPart.CFrame
    
    if target:IsA("Model") and target.PrimaryPart then
        cfTarget = target.PrimaryPart.CFrame
    end

    local offsetFrente = cfTarget.LookVector
    if targetPart.Name == "Pantalla" then
        offsetFrente = -cfTarget.RightVector
    elseif targetPart.Name == "MainScreen" then
        offsetFrente = cfTarget.LookVector
    end

    local posFinal = cfTarget.Position + (offsetFrente * 3.5)
    local targetLook = Vector3.new(targetPart.Position.X, rootPart.Position.Y, targetPart.Position.Z)

    rootPart.CFrame = CFrame.lookAt(posFinal, targetLook)
end

-- WALLBANG
local function aplicarWallbang(targetPart)
    if targetPart and targetPart:IsA("BasePart") then
        pcall(function()
            targetPart.CanCollide = false
        end)
    end
end

-- EQUIPAR ARMA
local function equiparArma()
    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    
    if not character or not backpack or not humanoid then return end
    if character:FindFirstChild(nombreArma) then return end

    local tool = backpack:FindFirstChild(nombreArma)
    if tool then
        humanoid:EquipTool(tool)
    end
end

-- SIMULAR CLIC DE DISPARO
local function hacerClic()
    pcall(function()
        local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        task.wait(0.08)
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
    end)
end

-- RECARGAR
local function recargarArma()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
        task.wait(0.08)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
    end)
end

-- ATAQUE A UN OBJETIVO (ATM O CAJA REGISTRADORA)
local function atacarObjetivo(target, rootPart)
    local targetPart = obtenerParteObjetivo(target)
    if not targetPart then return false end

    aplicarWallbang(targetPart)

    posicionarFrenteObjetivo(target, targetPart, rootPart)
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)

    task.wait(1.2)

    equiparArma()
    rootPart.Anchored = true
    
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)

    -- Disparo 1
    hacerClic()
    task.wait(0.35)

    -- Disparo 2
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
    hacerClic()
    task.wait(0.25)

    -- Recarga
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
    recargarArma()

    task.wait(0.25)
    rootPart.Anchored = false

    task.wait(1.5)
    return true
end

-- BÚSQUEDA DE CAJAS REGISTRADORAS ACTIVAS EN WORKSPACE
local function obtenerCajasRegistradorasActivas()
    local listaCajas = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "Cash Register" and objetivoEstaActivo(obj) then
            table.insert(listaCajas, obj)
        end
    end
    return listaCajas
end

-- BUCLE PRINCIPAL DE FARM
local function mainFarmLoop()
    iniciarRecoleccionAutomatica()

    while running do
        if verificarMunicionAgotada() then
            irAComprarMunicion()
        end

        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        if not rootPart then
            task.wait(1)
            continue
        end

        local miniMap = workspace:FindFirstChild("miniMap")

        -- 1. BÚSQUEDA Y FILTRADO DE ATMS ACTIVOS
        local atmList = {}
        if miniMap then
            for _, obj in ipairs(miniMap:GetChildren()) do
                if obj.Name:lower():find("atm") and objetivoEstaActivo(obj) then
                    table.insert(atmList, obj)
                end
            end
        end

        -- 2. PRIORIDAD 1: SI HAY ATMS DISPONIBLES, FARMER ATMS
        if #atmList > 0 then
            for _, atm in ipairs(atmList) do
                if not running then break end
                if verificarMunicionAgotada() then irAComprarMunicion() end

                atacarObjetivo(atm, rootPart)
            end
        else
            -- 3. PRIORIDAD 2: SI NO HAY ATMS, FARMEAR CAJAS REGISTRADORAS
            local cajasActivas = obtenerCajasRegistradorasActivas()
            if #cajasActivas > 0 then
                -- Ataca una caja y vuelve al inicio del ciclo para reevaluar si ya reapareció algún ATM
                if running then
                    if verificarMunicionAgotada() then irAComprarMunicion() end
                    atacarObjetivo(cajasActivas[1], rootPart)
                end
            else
                -- Si no hay ni ATMs ni cajas activas, espera brevemente
                task.wait(1)
            end
        end
        
        task.wait(0.5)
    end
    
    detenerRecoleccionAutomatica()
end

-- BOTÓN DE CONTROL
toggleButton.MouseButton1Click:Connect(function()
    running = not running
    if running then
        toggleButton.Text = "STOP"
        toggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        equiparArma()
        task.spawn(mainFarmLoop)
    else
        toggleButton.Text = "START"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if rootPart then rootPart.Anchored = false end
        
        detenerRecoleccionAutomatica()
    end
end)
