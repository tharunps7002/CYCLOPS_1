function DisasterReliefResourceDistribution
% DisasterAid: rainfall-aware disaster relief decision-support GUI.
% FEATURES
%   1. Manage affected locations, six-digit Indian PIN codes and demand.
%   2. Add unlimited user-defined resource categories and stock quantities.
%   3. Register affected places manually, including PIN code and rainfall.
%   4. Prioritize using severity, affected population, days without aid,
%      and rainfall; calculate demand-capped integer allocations.
%   5. Display shortage reports, chart allocations and log actions.
% IMPORTANT
%   - Fully offline: no API requests and no CSV file generation.
%   - Data remain in memory during this app session; enter verified values.
%   - This is decision support, not a dispatch order or emergency authority.
%   - Rainfall score is a transparent heuristic, not a trained prediction model.
%

    app = struct();

    % ------------------------- DEMO DATA -------------------------------
    app.Villages = table( ...
        ["Village A"; "Village B"; "Village C"; "Village D"; "Village E"], ...
        ["641001"; "641002"; "641003"; "641004"; "641005"], ...
        [1000; 500; 1500; 700; 800], ...
        ["Critical"; "Medium"; "Critical"; "High"; "High"], ...
        [800; 300; 1000; 500; 450], ...
        [1200; 600; 1800; 900; 1000], ...
        [120; 80; 200; 100; 160], ...
        [2; 1; 3; 2; 2], ...
        [45; 12; 68; 28; 35], ...
        'VariableNames', {'Village','PINCode','PeopleAffected','Severity','FoodNeed','WaterNeed','MedicineNeed','DaysWithoutAid','RainfallMM'});

    app.Inventory = table( ...
        ["Food packets"; "Water units"; "Medicine kits"], ...
        [1500; 2500; 350], ...
        'VariableNames', {'Resource','Available'});

    app.Allocations = table();
    app.HasAllocation = false;
    app.LogLines = strings(0,1);

    % ------------------------- MAIN WINDOW -----------------------------
    app.Fig = uifigure( ...
        'Name', 'DisasterAid | Intelligent Relief Distribution', ...
        'Position', [80 60 1450 850], ...
        'Color', [0.055 0.075 0.11]);

    root = uigridlayout(app.Fig, [5 1]);
    root.RowHeight = {82, 100, '1x', 245, 35};
    root.Padding = [16 14 16 12];
    root.RowSpacing = 12;
    root.BackgroundColor = [0.055 0.075 0.11];

    % ------------------------- HEADER ----------------------------------
    header = uipanel(root, 'BorderType','none', 'BackgroundColor',[0.08 0.12 0.18]);
    header.Layout.Row = 1;
    hg = uigridlayout(header,[2 2]);
    hg.RowHeight = {42,25};
    hg.ColumnWidth = {'1x', 430};
    hg.Padding = [18 8 18 8];
    hg.BackgroundColor = [0.08 0.12 0.18];

    titleLabel = uilabel(hg, ...
        'Text','DISASTERAID  |  SMART RELIEF DISTRIBUTION', ...
        'FontSize',22,'FontWeight','bold','FontColor',[0.92 0.96 1.00]);
    titleLabel.Layout.Row = 1;
    titleLabel.Layout.Column = 1;

    subtitleLabel = uilabel(hg, ...
        'Text','PIN-code lookup • rainfall-aware priority • scarcity-aware resource allocation', ...
        'FontSize',12,'FontColor',[0.65 0.76 0.88]);
    subtitleLabel.Layout.Row = 2;
    subtitleLabel.Layout.Column = 1;

    statusLabel = uilabel(hg, ...
        'Text','● READY  |  Demo data loaded', ...
        'FontSize',13,'FontWeight','bold','HorizontalAlignment','right', ...
        'FontColor',[0.45 0.90 0.68]);
    statusLabel.Layout.Row = [1 2];
    statusLabel.Layout.Column = 2;

    % ------------------------- KPI CARDS -------------------------------
    kpiPanel = uipanel(root,'BorderType','none','BackgroundColor',[0.055 0.075 0.11]);
    kpiPanel.Layout.Row = 2;
    kg = uigridlayout(kpiPanel,[1 4]);
    kg.ColumnWidth = {'1x','1x','1x','1x'};
    kg.Padding = [0 0 0 0];
    kg.ColumnSpacing = 12;
    kg.BackgroundColor = [0.055 0.075 0.11];

    app.KpiPeople = makeKpiCard(kg,'PEOPLE AFFECTED','0',[0.13 0.20 0.29]);
    app.KpiFood = makeKpiCard(kg,'FOOD PACKETS AVAILABLE','0',[0.13 0.20 0.29]);
    app.KpiWater = makeKpiCard(kg,'WATER UNITS AVAILABLE','0',[0.13 0.20 0.29]);
    app.KpiCritical = makeKpiCard(kg,'CRITICAL LOCATIONS','0',[0.13 0.20 0.29]);

    % ------------------------- MIDDLE AREA -----------------------------
    mid = uigridlayout(root,[1 2]);
    mid.Layout.Row = 3;
    mid.ColumnWidth = {'1.35x','1x'};
    mid.ColumnSpacing = 12;
    mid.Padding = [0 0 0 0];
    mid.BackgroundColor = [0.055 0.075 0.11];

    villagePanel = uipanel(mid,'Title','  AFFECTED LOCATIONS & REQUIREMENTS  ', ...
        'FontWeight','bold','FontSize',12, ...
        'ForegroundColor',[0.90 0.94 1.00], ...
        'BackgroundColor',[0.08 0.12 0.18]);
    villagePanel.Layout.Row = 1;
    villagePanel.Layout.Column = 1;

    vg = uigridlayout(villagePanel,[2 1]);
    vg.RowHeight = {'1x',34};
    vg.Padding = [10 10 10 8];
    vg.RowSpacing = 8;
    vg.BackgroundColor = [0.08 0.12 0.18];

    app.VillageTable = uitable(vg, ...
        'Data',app.Villages, ...
        'ColumnName',{'Village','PIN code','People affected','Severity','Food need','Water need','Medicine need','Days without aid','Rainfall (mm)'}, ...
        'ColumnEditable',[true true true true true true true true true], ...
        'ColumnWidth',{115 75 90 85 80 80 90 95 85}, ...
        'FontSize',11, ...
        'BackgroundColor',[1 1 1; 0.94 0.97 1]);
    app.VillageTable.Layout.Row = 1;
    app.VillageTable.Layout.Column = 1;

    villageHint = uilabel(vg, ...
        'Text','Edit cells directly. Use six-digit Indian PIN codes; rainfall is in mm. Numeric values must be non-negative whole numbers except rainfall.', ...
        'FontSize',10,'FontColor',[0.72 0.80 0.90]);
    villageHint.Layout.Row = 2;
    villageHint.Layout.Column = 1;

    rightPanel = uipanel(mid,'Title','  INVENTORY & ACTIONS  ', ...
        'FontWeight','bold','FontSize',12, ...
        'ForegroundColor',[0.90 0.94 1.00], ...
        'BackgroundColor',[0.08 0.12 0.18]);
    rightPanel.Layout.Row = 1;
    rightPanel.Layout.Column = 2;

    rg = uigridlayout(rightPanel,[4 1]);
    rg.RowHeight = {150, 54, 54, '1x'};
    rg.Padding = [12 10 12 10];
    rg.RowSpacing = 10;
    rg.BackgroundColor = [0.08 0.12 0.18];

    app.InventoryTable = uitable(rg, ...
        'Data',app.Inventory, ...
        'ColumnName',{'Resource','Available stock'}, ...
        'ColumnEditable',[false true], ...
        'ColumnWidth',{190 130}, ...
        'FontSize',12, ...
        'BackgroundColor',[1 1 1; 0.94 0.97 1]);
    app.InventoryTable.Layout.Row = 1;
    app.InventoryTable.Layout.Column = 1;

    actionRow1 = uigridlayout(rg,[1 2]);
    actionRow1.Layout.Row = 2;
    actionRow1.ColumnWidth = {'1x','1x'};
    actionRow1.Padding = [0 0 0 0];
    actionRow1.ColumnSpacing = 8;
    actionRow1.BackgroundColor = [0.08 0.12 0.18];

    allocateBtn = uibutton(actionRow1,'push', ...
        'Text','⚡  CALCULATE ALLOCATION', ...
        'FontWeight','bold','FontSize',12, ...
        'BackgroundColor',[0.12 0.48 0.78], ...
        'FontColor',[1 1 1], ...
        'ButtonPushedFcn',@onAllocate);
    allocateBtn.Layout.Row = 1;
    allocateBtn.Layout.Column = 1;

    addSupplyBtn = uibutton(actionRow1,'push', ...
        'Text','＋  ADD SUPPLY', ...
        'FontWeight','bold','FontSize',12, ...
        'BackgroundColor',[0.12 0.55 0.38], ...
        'FontColor',[1 1 1], ...
        'ButtonPushedFcn',@onAddSupply);
    addSupplyBtn.Layout.Row = 1;
    addSupplyBtn.Layout.Column = 2;

    actionRow2 = uigridlayout(rg,[1 4]);
    actionRow2.Layout.Row = 3;
    actionRow2.ColumnWidth = {'1x','1.15x','1x','1x'};
    actionRow2.Padding = [0 0 0 0];
    actionRow2.ColumnSpacing = 8;
    actionRow2.BackgroundColor = [0.08 0.12 0.18];

    addVillageBtn = uibutton(actionRow2,'push','Text','＋ Add Village', ...
        'BackgroundColor',[0.20 0.28 0.40],'FontColor',[1 1 1], ...
        'ButtonPushedFcn',@onAddVillage);
    addVillageBtn.Layout.Row = 1; addVillageBtn.Layout.Column = 1;

    addResourceBtn = uibutton(actionRow2,'push','Text','＋ Add Resource', ...
        'BackgroundColor',[0.12 0.40 0.56],'FontColor',[1 1 1], ...
        'ButtonPushedFcn',@onAddResource);
    addResourceBtn.Layout.Row = 1; addResourceBtn.Layout.Column = 2;

    removePlaceBtn = uibutton(actionRow2,'push','Text','－ Remove Place', ...
        'BackgroundColor',[0.20 0.28 0.40],'FontColor',[1 1 1], ...
        'ButtonPushedFcn',@onRemoveVillage);
    removePlaceBtn.Layout.Row = 1; removePlaceBtn.Layout.Column = 3;

    mapBtn = uibutton(actionRow2,'push','Text','🗺 MAP', ...
        'BackgroundColor',[0.12 0.40 0.56],'FontColor',[1 1 1], ...
        'FontWeight','bold', ...
        'ButtonPushedFcn',@onMap);
    mapBtn.Layout.Row = 1;
    mapBtn.Layout.Column = 4;

    app.ExplainLabel = uitextarea(rg, ...
        'Value',{'SYSTEM STATUS: Ready.'; ...
                 '1. Review village requirements.'; ...
                 '2. Verify available inventory.'; ...
                 '3. Calculate allocation to generate recommendations.'}, ...
        'Editable','off','FontSize',11, ...
        'BackgroundColor',[0.045 0.065 0.095], ...
        'FontColor',[0.82 0.88 0.95]);
    app.ExplainLabel.Layout.Row = 4;
    app.ExplainLabel.Layout.Column = 1;

    % ------------------------- OUTPUT AREA -----------------------------
    out = uigridlayout(root,[1 2]);
    out.Layout.Row = 4;
    out.ColumnWidth = {'1.45x','1x'};
    out.ColumnSpacing = 12;
    out.Padding = [0 0 0 0];
    out.BackgroundColor = [0.055 0.075 0.11];

    allocationPanel = uipanel(out,'Title','  RECOMMENDED ALLOCATION & SHORTAGES  ', ...
        'FontWeight','bold','FontSize',12, ...
        'ForegroundColor',[0.90 0.94 1.00], ...
        'BackgroundColor',[0.08 0.12 0.18]);
    allocationPanel.Layout.Row = 1;
    allocationPanel.Layout.Column = 1;

    ag = uigridlayout(allocationPanel,[1 1]);
    ag.Padding = [10 10 10 10];
    ag.BackgroundColor = [0.08 0.12 0.18];

    app.AllocationTable = uitable(ag, ...
        'Data',table(), ...
        'ColumnName',{}, ...
        'FontSize',11, ...
        'BackgroundColor',[1 1 1; 0.94 0.97 1]);
    app.AllocationTable.Layout.Row = 1;
    app.AllocationTable.Layout.Column = 1;

    chartPanel = uipanel(out,'Title','  RESOURCE ALLOCATION OVERVIEW  ', ...
        'FontWeight','bold','FontSize',12, ...
        'ForegroundColor',[0.90 0.94 1.00], ...
        'BackgroundColor',[0.08 0.12 0.18]);
    chartPanel.Layout.Row = 1;
    chartPanel.Layout.Column = 2;

    cg = uigridlayout(chartPanel,[2 1]);
    cg.RowHeight = {'1x', 70};
    cg.Padding = [10 10 10 8];
    cg.RowSpacing = 6;
    cg.BackgroundColor = [0.08 0.12 0.18];

    app.Axes = uiaxes(cg);
    app.Axes.Layout.Row = 1;
    app.Axes.Layout.Column = 1;
    app.Axes.Color = [0.08 0.12 0.18];
    app.Axes.XColor = [0.85 0.90 0.97];
    app.Axes.YColor = [0.85 0.90 0.97];
    app.Axes.GridColor = [0.35 0.42 0.52];
    app.Axes.Title.String = 'Allocated resources by village';
    app.Axes.Title.Color = [0.92 0.96 1.00];
    app.Axes.FontSize = 10;
    grid(app.Axes,'on');

    app.LogArea = uitextarea(cg, ...
        'Value',{'Activity log: application initialized.'}, ...
        'Editable','off','FontSize',10, ...
        'BackgroundColor',[0.045 0.065 0.095], ...
        'FontColor',[0.72 0.84 0.92]);
    app.LogArea.Layout.Row = 2;
    app.LogArea.Layout.Column = 1;

    % ------------------------- FOOTER ----------------------------------
    footer = uilabel(root, ...
        'Text','OFFLINE DECISION SUPPORT  •  Enter verified field data manually  •  Allocation is a recommendation, not a dispatch order', ...
        'FontSize',10,'HorizontalAlignment','center', ...
        'FontColor',[0.55 0.65 0.77]);
    footer.Layout.Row = 5;

    refreshKpis();
    addLog('Application initialized with simulated demonstration data.');
    updateStatus('READY  |  Review data, then calculate allocation', [0.45 0.90 0.68]);

    % ========================= CALLBACKS ===============================

    function onAllocate(~,~)
        try
            V = app.VillageTable.Data;
            I = app.InventoryTable.Data;

            [V, I] = validateAndNormalize(V, I);
            app.VillageTable.Data = V;
            app.InventoryTable.Data = I;

            scores = calculatePriorityScores(V);
            foodAlloc = cappedWeightedAllocation(V.FoodNeed, scores, I.Available(1));
            waterAlloc = cappedWeightedAllocation(V.WaterNeed, scores, I.Available(2));
            medAlloc = cappedWeightedAllocation(V.MedicineNeed, scores, I.Available(3));

            app.Allocations = table( ...
                V.Village, V.PINCode, V.PeopleAffected, V.Severity, V.DaysWithoutAid, V.RainfallMM, scores, ...
                V.FoodNeed, foodAlloc, max(0,V.FoodNeed-foodAlloc), ...
                V.WaterNeed, waterAlloc, max(0,V.WaterNeed-waterAlloc), ...
                V.MedicineNeed, medAlloc, max(0,V.MedicineNeed-medAlloc), ...
                'VariableNames', {'Village','PINCode','PeopleAffected','Severity','DaysWithoutAid','RainfallMM','PriorityScore', ...
                'FoodNeed','FoodAllocated','FoodShortage', ...
                'WaterNeed','WaterAllocated','WaterShortage', ...
                'MedicineNeed','MedicineAllocated','MedicineShortage'});

            % Allocate every user-added resource using the same transparent priority weights.
            for rr = 4:height(I)
                resourceName = string(I.Resource(rr));
                field = findResourceField(V.Properties.VariableNames,resourceName);
                if field == "", continue; end
                demand = double(V.(char(field)));
                allocated = cappedWeightedAllocation(demand,scores,I.Available(rr));
                needName = char(field);
                allocName = matlab.lang.makeValidName(char(resourceName + "Allocated"));
                shortageName = matlab.lang.makeValidName(char(resourceName + "Shortage"));
                app.Allocations.(needName) = demand;
                app.Allocations.(allocName) = allocated;
                app.Allocations.(shortageName) = max(0,demand-allocated);
            end

            app.HasAllocation = true;
            app.AllocationTable.Data = app.Allocations;
            updateChart();
            refreshKpis();

            totalFood = sum(foodAlloc);
            totalWater = sum(waterAlloc);
            totalMed = sum(medAlloc);
            shortages = sum(app.Allocations.FoodShortage) + ...
                        sum(app.Allocations.WaterShortage) + ...
                        sum(app.Allocations.MedicineShortage);

            explain = {
                'ALLOCATION COMPLETE';
                sprintf('Food allocated: %g / %g packets', totalFood, I.Available(1));
                sprintf('Water allocated: %g / %g units', totalWater, I.Available(2));
                sprintf('Medicine allocated: %g / %g kits', totalMed, I.Available(3));
                sprintf('Total unmet demand across all resource types: %g units', shortages);
                'Priority combines severity, affected population, days without aid, and rainfall.';
                'Check the shortage columns before approving any dispatch.'
                };
            app.ExplainLabel.Value = explain;
            addLog(sprintf('Allocation calculated. Food=%g, Water=%g, Medicine=%g allocated.', ...
                totalFood,totalWater,totalMed));
            updateStatus('ALLOCATION READY  |  Review shortages before dispatch', [0.98 0.75 0.30]);

        catch ME
            uialert(app.Fig, sprintf('Unable to calculate allocation:\n%s', ME.message), ...
                'Input or Allocation Error','Icon','error');
            addLog("ERROR: " + string(ME.message));
            updateStatus('ERROR  |  Check input values', [1.00 0.40 0.40]);
        end
    end

    function onAddSupply(~,~)
        I = app.InventoryTable.Data;
        choices = cellstr(string(I.Resource));
        [idx, ok] = listdlg('PromptString','Select the supply to add:', ...
            'SelectionMode','single','ListString',choices,'ListSize',[220 110]);
        if ~ok
            return;
        end
        answer = inputdlg({'Enter additional quantity (whole number):'}, ...
            'Add Supply', [1 42], {'100'});
        if isempty(answer)
            return;
        end
        qty = str2double(answer{1});
        if ~isfinite(qty) || qty < 0 || qty ~= floor(qty)
            uialert(app.Fig,'Quantity must be a non-negative whole number.','Invalid Quantity');
            return;
        end
        I = app.InventoryTable.Data;
        I.Available(idx) = I.Available(idx) + qty;
        app.InventoryTable.Data = I;
        app.HasAllocation = false;
        refreshKpis();
        addLog(sprintf('Added %g units to inventory: %s.',qty,choices{idx}));
        updateStatus('INVENTORY UPDATED  |  Recalculate allocation', [0.45 0.90 0.68]);
    end

    function onAddVillage(~,~)
        answer = inputdlg( ...
            {'Village / location name:','Indian PIN code (6 digits):','People affected:', ...
             'Severity (Critical, High, Medium, Low):','Food packets needed:', ...
             'Water units needed:','Medicine kits needed:','Days without aid:','Rainfall in last/next day (mm):'}, ...
             'Register Affected Location',[1 48], ...
             {'New Village','641001','250','High','200','300','40','1','25'});
        if isempty(answer)
            return;
        end
        name = strtrim(string(answer{1}));
        pin = strtrim(string(answer{2}));
        people = str2double(answer{3});
        severity = normalizeSeverity(string(strtrim(answer{4})));
        food = str2double(answer{5});
        water = str2double(answer{6});
        medicine = str2double(answer{7});
        days = str2double(answer{8});
        rainfall = str2double(answer{9});

        numericValues = [people food water medicine days];
        if strlength(name)==0 || any(~isfinite(numericValues)) || ...
                any(numericValues < 0) || any(numericValues ~= floor(numericValues)) || ...
                ~isfinite(rainfall) || rainfall < 0
            uialert(app.Fig,'Enter a name and non-negative whole numbers for all numeric fields.','Invalid Village Data');
            return;
        end
        if ~any(severity == ["Critical","High","Medium","Low"])
            uialert(app.Fig,'Severity must be Critical, High, Medium, or Low.','Invalid Severity');
            return;
        end
        if strlength(pin) ~= 6 || any(~isstrprop(char(pin),'digit'))
            uialert(app.Fig,'Indian PIN code must contain exactly six digits.','Invalid PIN code');
            return;
        end

        V = app.VillageTable.Data;
        if any(strcmpi(string(V.Village),name))
            uialert(app.Fig,'A village with this name already exists. Use a unique name.','Duplicate Location');
            return;
        end
        baseRow = table(name,pin,people,severity,food,water,medicine,days,rainfall, ...
            'VariableNames',{'Village','PINCode','PeopleAffected','Severity','FoodNeed','WaterNeed','MedicineNeed','DaysWithoutAid','RainfallMM'});
        newRow = table();
        for c = 1:width(V)
            col = V.Properties.VariableNames{c};
            if ismember(col,baseRow.Properties.VariableNames)
                newRow.(col) = baseRow.(col);
            else
                newRow.(col) = 0;
            end
        end
        newRow = newRow(:,V.Properties.VariableNames);
        app.VillageTable.Data = [V; newRow];
        app.HasAllocation = false;
        refreshKpis();
        addLog("Registered new affected location: " + name);
        updateStatus('LOCATION ADDED  |  Recalculate allocation', [0.45 0.90 0.68]);
    end

    function onAddResource(~,~)
        % Register a new resource category without external APIs or files.
        answer = inputdlg({'Resource name:','Available quantity (whole number):'}, ...
            'Add Custom Resource',[1 45],{'Blankets','100'});
        if isempty(answer), return; end
        resourceName = strtrim(string(answer{1}));
        qty = str2double(answer{2});
        if strlength(resourceName)==0 || ~isfinite(qty) || qty<0 || qty~=floor(qty)
            uialert(app.Fig,'Enter a resource name and a non-negative whole-number stock quantity.','Invalid Resource');
            return;
        end
        I = app.InventoryTable.Data;
        if any(strcmpi(strtrim(string(I.Resource)),resourceName))
            uialert(app.Fig,'That resource already exists. Use Add Supply to increase its stock.','Duplicate Resource');
            return;
        end
        field = makeResourceField(resourceName);
        V = app.VillageTable.Data;
        if ismember(field,V.Properties.VariableNames)
            field = matlab.lang.makeUniqueStrings(field,V.Properties.VariableNames);
        end
        V.(field) = zeros(height(V),1);
        app.VillageTable.Data = V;
        I = [I; table(resourceName,qty,'VariableNames',I.Properties.VariableNames)];
        app.InventoryTable.Data = I;
        app.VillageTable.ColumnName = friendlyVillageColumnNames(V.Properties.VariableNames);
        app.VillageTable.ColumnEditable = true(1,width(V));
        app.VillageTable.ColumnFormat = repmat({[]},1,width(V));
        app.HasAllocation = false;
        refreshKpis();
        addLog("Added resource category: " + resourceName);
        app.ExplainLabel.Value = {'CUSTOM RESOURCE ADDED'; ...
            ['Resource: ' char(resourceName)]; ...
            'A matching Need column was added to the location table.'; ...
            'Enter the demand for each place, then calculate allocation.'};
        updateStatus('RESOURCE ADDED  |  Enter location demand', [0.45 0.90 0.68]);
    end

    function onRemoveVillage(~,~)
        V = app.VillageTable.Data;
        if isempty(V) || height(V)==0
            uialert(app.Fig,'There are no places to remove.','Remove Place');
            return;
        end
        [idx,ok] = listdlg('PromptString','Select an affected place to remove:', ...
            'SelectionMode','single','ListString',cellstr(string(V.Village)), ...
            'ListSize',[300 180]);
        if ~ok, return; end
        removedName = string(V.Village(idx));
        V(idx,:) = [];
        app.VillageTable.Data = V;
        app.HasAllocation = false;
        app.AllocationTable.Data = table();
        refreshKpis();
        addLog("Removed affected place: " + removedName);
        updateStatus('PLACE REMOVED  |  Recalculate allocation', [0.45 0.90 0.68]);
    end

    function onMap(~,~)
        % Open the requested official NDEM portal in the system browser.
        % This preserves the website's own map layers and live updates.
        mapURL = 'https://ndem.nrsc.gov.in/#/';
        try
            web(mapURL,'-browser');
            addLog('Opened the NDEM map portal in the web browser.');
            updateStatus('MAP OPENED  |  NDEM portal launched in browser', ...
                [0.45 0.90 0.68]);
        catch ME
            uialert(app.Fig, ...
                sprintf('Unable to open the NDEM map portal.\\n%s',ME.message), ...
                'Map Open Error','Icon','error');
            addLog("MAP ERROR: " + string(ME.message));
            updateStatus('MAP ERROR  |  Open the NDEM URL manually', ...
                [1.00 0.40 0.40]);
        end
    end

    % ========================= UI HELPERS ==============================

    function refreshKpis()
        try
            V = app.VillageTable.Data;
            I = app.InventoryTable.Data;
            if isempty(V) || height(V)==0
                people = 0; critical = 0;
            else
                people = sum(double(V.PeopleAffected),'omitnan');
                critical = sum(strcmpi(string(V.Severity),"Critical"));
            end
            app.KpiPeople.Value.Text = formatNumber(people);
            foodIdx = find(strcmpi(string(I.Resource),'Food packets'),1);
            waterIdx = find(strcmpi(string(I.Resource),'Water units'),1);
            if isempty(foodIdx), foodStock=0; else, foodStock=I.Available(foodIdx); end
            if isempty(waterIdx), waterStock=0; else, waterStock=I.Available(waterIdx); end
            app.KpiFood.Value.Text = formatNumber(foodStock);
            app.KpiWater.Value.Text = formatNumber(waterStock);
            app.KpiCritical.Value.Text = formatNumber(critical);
        catch
            % Keep the interface responsive while a user is editing a cell.
        end
    end

    function updateChart()
        if isempty(app.Allocations) || height(app.Allocations)==0
            cla(app.Axes);
            return;
        end
        cla(app.Axes);
        vals = [app.Allocations.FoodAllocated, ...
                app.Allocations.WaterAllocated, ...
                app.Allocations.MedicineAllocated];
        bar(app.Axes,vals,'grouped');
        app.Axes.XTick = 1:height(app.Allocations);
        app.Axes.XTickLabel = cellstr(app.Allocations.Village);
        app.Axes.XTickLabelRotation = 25;
        app.Axes.XColor = [0.85 0.90 0.97];
        app.Axes.YColor = [0.85 0.90 0.97];
        app.Axes.Title.String = 'Allocated quantities by village';
        app.Axes.Title.Color = [0.92 0.96 1.00];
        app.Axes.XLabel.String = 'Affected location';
        app.Axes.YLabel.String = 'Allocated units';
        app.Axes.XLabel.Color = [0.85 0.90 0.97];
        app.Axes.YLabel.Color = [0.85 0.90 0.97];
        legend(app.Axes,{'Food','Water','Medicine'},'TextColor',[0.90 0.94 1.00], ...
            'Location','northoutside','Orientation','horizontal');
        grid(app.Axes,'on');
    end

    function addLog(message)
        timestamp = string(datetime('now','Format','HH:mm:ss'));
        app.LogLines(end+1,1) = "[" + timestamp + "] " + string(message);
        if numel(app.LogLines) > 8
            app.LogLines = app.LogLines(end-7:end);
        end
        app.LogArea.Value = cellstr(app.LogLines);
    end

    function updateStatus(message,color)
        statusLabel.Text = "● " + string(message);
        statusLabel.FontColor = color;
    end
end

% =========================== LOCAL FUNCTIONS ===========================

function field = makeResourceField(resourceName)
% Convert a custom resource label to a predictable MATLAB table variable.
    field = string(matlab.lang.makeValidName(char(strtrim(resourceName) + "Need")));
    if strlength(field)==0 || ~isletter(extractBetween(field,1,1))
        field = "ResourceNeed";
    end
end

function field = findResourceField(variableNames,resourceName)
% Locate the demand column corresponding to a custom inventory resource.
    field = "";
    candidate = makeResourceField(resourceName);
    if any(strcmp(variableNames,char(candidate)))
        field = candidate;
    end
end

function names = friendlyVillageColumnNames(variableNames)
% User-facing names for editable location table columns.
    names = variableNames;
    labels = containers.Map(...
        {'Village','PINCode','PeopleAffected','Severity','FoodNeed','WaterNeed', ...
         'MedicineNeed','DaysWithoutAid','RainfallMM'}, ...
        {'Place','Indian PIN','People affected','Severity','Food need', ...
         'Water need','Medicine need','Days without aid','Rainfall (mm)'});
    for n = 1:numel(variableNames)
        key = variableNames{n};
        if isKey(labels,key)
            names{n} = labels(key);
        elseif endsWith(key,'Need')
            names{n} = [extractBefore(key,strlength(key)-3) ' need'];
        end
    end
end

function cardValue = makeKpiCard(parent, heading, initialValue, bgColor)
    card = uipanel(parent,'BorderType','line','BackgroundColor',bgColor, ...
        'ForegroundColor',[0.20 0.29 0.41]);
    grid = uigridlayout(card,[2 1]);
    grid.RowHeight = {25,'1x'};
    grid.Padding = [12 8 12 8];
    grid.RowSpacing = 2;
    grid.BackgroundColor = bgColor;

    label = uilabel(grid,'Text',heading,'FontSize',9,'FontWeight','bold', ...
        'FontColor',[0.67 0.78 0.90]);
    label.Layout.Row = 1;
    label.Layout.Column = 1;

    value = uilabel(grid,'Text',initialValue,'FontSize',24,'FontWeight','bold', ...
        'FontColor',[0.96 0.98 1.00]);
    value.Layout.Row = 2;
    value.Layout.Column = 1;
    cardValue = struct('Panel',card,'Heading',label,'Value',value);
end

function [V,I] = validateAndNormalize(V,I)
    requiredV = {'Village','PINCode','PeopleAffected','Severity','FoodNeed','WaterNeed','MedicineNeed','DaysWithoutAid','RainfallMM'};
    requiredI = {'Resource','Available'};
    if ~istable(V) || ~all(ismember(requiredV,V.Properties.VariableNames))
        error('Village table columns are missing or have been changed.');
    end
    if ~istable(I) || ~all(ismember(requiredI,I.Properties.VariableNames)) || height(I) < 3
        error('Inventory table must contain Food packets, Water units, and Medicine kits.');
    end
    V.Village = strtrim(string(V.Village));
    V.PINCode = strtrim(string(V.PINCode));
    if any(strlength(V.PINCode) ~= 6 | cellfun(@(x) any(~isstrprop(x,'digit')),cellstr(V.PINCode)))
        error('Every Indian PIN code must contain exactly six digits.');
    end
    V.Severity = normalizeSeverity(strtrim(string(V.Severity)));
    if any(ismissing(V.Village) | strlength(V.Village)==0)
        error('Every location must have a name.');
    end
    if numel(unique(lower(V.Village))) ~= height(V)
        error('Village names must be unique.');
    end
    allowed = ["Critical","High","Medium","Low"];
    if any(~ismember(V.Severity,allowed))
        error('Severity must be Critical, High, Medium, or Low.');
    end
    numericNames = {'PeopleAffected','FoodNeed','WaterNeed','MedicineNeed','DaysWithoutAid'};
    for k = 1:numel(numericNames)
        name = numericNames{k};
        x = V.(name);
        if ~isnumeric(x) || any(~isfinite(x)) || any(x < 0) || any(x ~= floor(x))
            error('%s must contain non-negative whole numbers.',name);
        end
    end
    if ~isnumeric(V.RainfallMM) || any(~isfinite(V.RainfallMM)) || any(V.RainfallMM < 0)
        error('RainfallMM must contain finite, non-negative rainfall values in mm.');
    end
    if any(~isfinite(I.Available)) || any(I.Available < 0) || any(I.Available ~= floor(I.Available))
        error('Inventory quantities must be non-negative whole numbers.');
    end
    % Enforce known resource ordering so allocation always maps to correct stock.
    expected = ["Food packets";"Water units";"Medicine kits"];
    if ~all(ismember(expected,string(I.Resource)))
        error('Inventory must include Food packets, Water units, and Medicine kits.');
    end
    [~,order] = ismember(expected,string(I.Resource));
    I = I(order,:);
end

function scores = calculatePriorityScores(V)
    % Transparent rule-based score; this is not a trained AI model.
    severity = zeros(height(V),1);
    severity(strcmpi(V.Severity,"Critical")) = 100;
    severity(strcmpi(V.Severity,"High")) = 70;
    severity(strcmpi(V.Severity,"Medium")) = 40;
    severity(strcmpi(V.Severity,"Low")) = 20;

    people = double(V.PeopleAffected);
    if max(people) > 0
        peopleScore = 25 .* people ./ max(people);
    else
        peopleScore = zeros(size(people));
    end

    days = double(V.DaysWithoutAid);
    if max(days) > 0
        daysScore = 25 .* days ./ max(days);
    else
        daysScore = zeros(size(days));
    end

    rainfall = double(V.RainfallMM);
    if max(rainfall) > 0
        rainfallScore = 25 .* rainfall ./ max(rainfall);
    else
        rainfallScore = zeros(size(rainfall));
    end

    scores = severity + peopleScore + daysScore + rainfallScore;
    scores = max(scores,1);
end

function allocation = cappedWeightedAllocation(demand, weights, available)
    % Weighted, demand-capped integer allocation.
    % Guarantees: allocation <= demand, allocation >= 0, sum(allocation) <= stock.
    demand = round(double(demand(:)));
    weights = double(weights(:));
    available = floor(double(available));

    allocation = zeros(size(demand));
    if isempty(demand) || available <= 0 || sum(demand) <= 0
        return;
    end
    if sum(demand) <= available
        allocation = demand;
        return;
    end

    remaining = min(available,sum(demand));
    active = demand > 0;

    % Iterative weighted water-filling: locations that hit demand caps leave
    % the active set; remaining stock is redistributed among other locations.
    maxIterations = numel(demand) + 2;
    iteration = 0;
    while remaining > 0 && any(active) && iteration < maxIterations
        iteration = iteration + 1;
        activeIdx = find(active);
        w = weights(activeIdx);
        w(~isfinite(w) | w <= 0) = 1;
        ideal = remaining .* w ./ sum(w);
        capacity = demand(activeIdx) - allocation(activeIdx);

        capped = ideal >= capacity;
        if any(capped)
            cappedIdx = activeIdx(capped);
            give = capacity(capped);
            allocation(cappedIdx) = allocation(cappedIdx) + give;
            remaining = remaining - sum(give);
            active(cappedIdx) = false;
            continue;
        end

        base = floor(ideal);
        base = min(base,capacity);
        allocation(activeIdx) = allocation(activeIdx) + base;
        remaining = available - sum(allocation);

        % Allocate residual integer units by largest fractional remainder,
        % breaking ties by priority weight. This avoids losing stock to rounding.
        if remaining > 0
            capacityLeft = demand(activeIdx) - allocation(activeIdx);
            fractions = ideal - floor(ideal);
            candidates = find(capacityLeft > 0);
            if isempty(candidates)
                break;
            end
            ranking = [fractions(candidates), w(candidates)];
            [~,ord] = sortrows(ranking,[-1 -2]);
            chosen = candidates(ord);
            units = min(remaining,numel(chosen));
            for j = 1:units
                idx = activeIdx(chosen(j));
                allocation(idx) = allocation(idx) + 1;
            end
            remaining = available - sum(allocation);
        end
        break;
    end

    % Defensive final fill if any stock remains due to unusual edge cases.
    remaining = available - sum(allocation);
    while remaining > 0
        capacity = demand - allocation;
        candidates = find(capacity > 0);
        if isempty(candidates)
            break;
        end
        [~,order] = sortrows([weights(candidates), capacity(candidates)],[-1 -2]);
        candidates = candidates(order);
        for k = 1:numel(candidates)
            if remaining <= 0
                break;
            end
            allocation(candidates(k)) = allocation(candidates(k)) + 1;
            remaining = remaining - 1;
        end
    end
end


function values = normalizeSeverity(values)
    % Normalize user-entered severity labels without calling MATLAB's graphics title().
    values = string(values);
    for i = 1:numel(values)
        token = lower(strtrim(values(i)));
        switch token
            case "critical"
                values(i) = "Critical";
            case "high"
                values(i) = "High";
            case "medium"
                values(i) = "Medium";
            case "low"
                values(i) = "Low";
            otherwise
                values(i) = strtrim(values(i));
        end
    end
end

function s = formatNumber(x)
    s = char(string(round(x)));
end

% ======================== PROJECT NOTES ================================
% Suggested MATLAB version: R2020b or newer (uifigure and table support).
% This edition is fully offline: no API calls and no CSV file generation.
% PIN code and rainfall values are entered manually from verified sources.
%
% INPUT DATA DICTIONARY
%   Village        Human-readable affected location name.
%   PINCode        Six-character Indian PIN code stored as text.
%   PeopleAffected Number of people estimated to be affected.
%   Severity       Critical, High, Medium, or Low.
%   FoodNeed       Requested food packets.
%   WaterNeed      Requested water units.
%   MedicineNeed   Requested medicine kits.
%   DaysWithoutAid Number of days since the last aid delivery.
%   RainfallMM     Daily precipitation estimate in millimetres.
%
% PRIORITY METHOD
%   Severity contribution: Critical=100, High=70, Medium=40, Low=20.
%   Population contribution: 0..25 normalized against the largest population.
%   Waiting-time contribution: 0..25 normalized against the largest waiting time.
%   Rainfall contribution: 0..25 normalized against the highest rainfall.
%   Total score is the sum of these contributions. This transparent rule is
%   intended for demonstrations and must be reviewed by disaster-management
%   professionals before real deployment. It does not account for every local
%   hazard, road closure, medical urgency, household vulnerability or logistics.
%
% ALLOCATION METHOD
%   Each resource is allocated separately. The routine caps every allocation
%   at local demand, never assigns negative units, and keeps total allocation
%   within available stock. Scarce stock is distributed by priority weights.
%   Equal/near-equal fractional allocations use deterministic tie-breaking.
%   Remaining unmet demand is explicitly shown as shortage in the output table.
%
% OPERATIONAL CHECKLIST
%   1. Confirm village names and PIN codes with local authorities.
%   2. Confirm the affected population and severity with verified field reports.
%   3. Confirm rainfall date, locality match, and weather source timestamp.
%   4. Confirm inventory quantities and measurement units.
%   5. Calculate allocation and review all shortage columns.
%   6. Have a responsible relief coordinator approve any dispatch decision.
%   7. Record approved allocations in the organization's approved system.
%
% TROUBLESHOOTING
%   PIN validation: confirm all six digits and correct the place manually.
%   Rainfall: enter a verified local measurement or estimate and note its source.
%   Allocation error: ensure every numeric field is finite and non-negative.
%
% EXTENSION IDEAS
%   Add verified district disaster-management feeds, river-gauge data, road
%   accessibility, shelter capacity, expiry dates, vehicle capacity, and a map.
%   Add a database only after access control, backups, and audit logging are set.
%   Add uncertainty intervals and data-source timestamps to rainfall records.
%   Custom resource names should be unique and clearly identify their measurement units.
%
% This software is provided as an educational prototype without warranties.
% Always use verified official information and local emergency procedures.
% ===================== END PROJECT NOTES ================================

% ======================== OFFLINE DATA NOTES ===========================
% DATA ENTRY GUIDANCE
% Enter each affected place as a separate row.
% Use the six-digit PIN field as text to preserve leading zeroes if applicable.
% Population and demand values should be checked against field reports.
% Rainfall values must be numeric millimetres and non-negative.
% Severity is a human-entered assessment, not an automated diagnosis.
% Custom resource demand fields are added when a custom resource is registered.
% Enter the demand for each place in the newly created column.
% The stock amount belongs in the inventory table.
% The allocation routine treats custom resource quantities as whole units.
% It does not convert between different units such as litres and bottles.
% Keep units consistent for each resource across all locations.
% If stock is less than total demand, shortages remain visible in the report.
% If stock exceeds total demand, the unused quantity is not assigned.
% A location with zero demand receives zero units of that resource.
% The priority score is a transparent heuristic for demonstration purposes.
% Review priorities with a qualified coordinator before acting on results.
% This application does not automatically contact emergency services.
% This application does not issue vehicle routes or dispatch orders.
% No personal data beyond the manually entered location details is required.
% Do not enter sensitive personal information about individual residents.
% The log is limited to recent actions to keep the interface compact.
% The reset action restores demonstration data and removes custom columns.
% Adding a place creates zero demand for all user-defined resource categories.
% Add custom resource categories before entering their per-place demand.
% Editing table values does not itself confirm that field data are accurate.
% Calculate allocation again after any changes to demand or stock.
% The chart focuses on the three standard resources for visual readability.
% The allocation table also contains custom resource results when configured.
% The app keeps changes in memory only while the MATLAB session is running.
% Closing the app discards unsaved manual changes in this offline edition.
% Keep a separate authorized record if retention is required by your organization.
% Confirm all stock quantities with the warehouse or distribution team.
% Confirm the reporting period associated with each rainfall value.
% Distinguish observed rainfall from forecast rainfall in your operational notes.
% Do not interpret forecast rainfall as a guarantee of actual conditions.
% Roads, bridges, shelter capacity, and access constraints are not modeled here.
% Medical urgency may require professional triage outside this score.
% Local laws and disaster-management protocols take precedence over this tool.
% The software is an educational prototype and must be independently tested.
% Test the app with small synthetic data before entering operational records.
% Check that every custom resource has a unique display name.
% Check that every demand column is filled with non-negative whole numbers.
% If a table column is accidentally renamed, restore its expected variable name.
% Keep the application source filename identical to its main function name.
% Correct filename: DisasterReliefResourceDistribution.m
% Correct command: DisasterReliefResourceDistribution
% Avoid filenames containing parentheses, spaces, or punctuation.
% Run the application from the MATLAB Current Folder containing this file.
% For classroom demonstration, identify all sample values as simulated data.
% The bundled sample villages are not verified live disaster reports.
% Do not treat sample rainfall numbers as a current weather feed.
% The attached PDF appeared to contain screenshot tables rather than extractable text.
% Therefore no exact PDF values are silently fabricated into the sample records.
% Manually transcribe and verify those values before using them operationally.
% ====================== END OFFLINE DATA NOTES =========================
% ===================== VALIDATION CHECKLIST ============================
% Before every demonstration, verify the following items manually.
% [ ] Each place has a non-empty and unique name.
% [ ] Each PIN code contains six numeric characters.
% [ ] Affected population is a non-negative whole number.
% [ ] Severity is one of Critical, High, Medium, or Low.
% [ ] Food demand is expressed in packets, not meals or kilograms.
% [ ] Water demand uses the same unit for every location.
% [ ] Medicine demand uses consistent kit units.
% [ ] Days without aid are entered as whole days.
% [ ] Rainfall is expressed in millimetres.
% [ ] Each custom resource has an unambiguous name.
% [ ] Each custom resource stock amount uses whole units.
% [ ] Demand for a custom resource is entered for each relevant place.
% [ ] Unneeded custom-resource demand is left at zero.
% [ ] Inventory values have been checked against actual stock.
% [ ] Allocation recommendations have been reviewed by a coordinator.
% [ ] Shortage values have been reviewed before any dispatch decision.
% [ ] Demonstration values are not mistaken for live operational records.
% [ ] Weather values have a known date and a trustworthy source.
% [ ] Location names and PIN codes have been verified independently.
% [ ] Any field uncertainty has been communicated to the decision maker.
% =======================================================================

% FINAL PROJECT CHECKS
% This source is intentionally a single MATLAB function file.
% Keep all local helper functions after the main function end.
% Use standard ASCII characters in names if your MATLAB environment requires it.
% The custom resource system is demand-capped and inventory-aware.
% Always run a test allocation after adding a custom resource.
% Confirm custom demand columns appear before entering real values.
% Verify output shortages against a hand-calculated small example.
% Confirm that total allocations never exceed the available stock.
% Confirm that no location receives more than its requested quantity.
% End of source-level implementation checklist.
