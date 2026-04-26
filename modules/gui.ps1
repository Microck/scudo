Set-StrictMode -Version Latest

function Get-ScudoGuiThemeDefinition {
    return [ordered]@{
        BgMain              = '#2B3031'
        BgSurface           = '#3B4243'
        BgSurfaceSelected   = '#4A5453'
        TextPrimary         = '#EAD6B8'
        TextMuted           = '#C4B392'
        Border              = '#5A6765'
        BorderStrong        = '#81A884'
        AccentPrimary       = '#81A884'
        AccentPrimaryHover  = '#92BC95'
        AccentPrimaryPressed = '#6E9071'
        AccentDanger        = '#CA4433'
        AccentDangerHover   = '#D85D4E'
        AccentDangerPressed = '#B43E2F'
        StatusConfigured    = '#81A884'
        StatusAction        = '#EAD6B8'
        StatusReboot        = '#C69C68'
        StatusAdvisory      = '#A0BAA2'
        StatusUnsupported   = '#8D8378'
        StatusError         = '#CA4433'
    }
}

function Get-ScudoGuiBrush {
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Hex)
    if ($brush -is [System.Windows.Freezable] -and $brush.CanFreeze) {
        $brush.Freeze()
    }
    return $brush
}

function Get-ScudoGuiStatusText {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    switch ($Status.State) {
        'already-configured' { return 'OK' }
        'needs-action' { return 'TODO' }
        'pending-reboot' { return 'REBOOT' }
        'advisory' { return 'INFO' }
        'unsupported' { return 'SKIP' }
        'error' { return 'ERROR' }
        default { return 'UNKNOWN' }
    }
}

function Get-ScudoGuiStateLabel {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    switch ($Status.State) {
        'already-configured' { return 'Configured' }
        'needs-action' { return 'Needs action' }
        'pending-reboot' { return 'Needs reboot' }
        'advisory' { return 'Guidance' }
        'unsupported' { return 'Unsupported' }
        'error' { return 'Error' }
        default { return 'Unknown' }
    }
}

function Get-ScudoGuiStatusResourceKey {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    switch ($Status.State) {
        'already-configured' { return 'StatusConfiguredBrush' }
        'needs-action' { return 'StatusActionBrush' }
        'pending-reboot' { return 'StatusRebootBrush' }
        'advisory' { return 'StatusAdvisoryBrush' }
        'unsupported' { return 'StatusUnsupportedBrush' }
        'error' { return 'StatusErrorBrush' }
        default { return 'StatusActionBrush' }
    }
}

function Get-ScudoGuiTierLabel {
    param(
        [Parameter(Mandatory)]
        [string]$Tier
    )

    switch ($Tier) {
        'baseline' { return 'baseline' }
        'strict' { return 'strict' }
        'guided' { return 'guided' }
        'optional' { return 'optional' }
        default { return $Tier }
    }
}

function Get-ScudoGuiAutomationLabel {
    param(
        [Parameter(Mandatory)]
        [string]$AutomationLevel
    )

    switch ($AutomationLevel) {
        'automatic' { return 'automatic' }
        'guided' { return 'guided input' }
        'check-only' { return 'check only' }
        'manual' { return 'manual step' }
        default { return $AutomationLevel }
    }
}

function Get-ScudoGuiSectionMap {
    $sectionMap = @{}
    foreach ($section in Get-ScudoSectionCatalog) {
        $sectionMap[$section.Id] = $section
    }

    return $sectionMap
}

function Get-ScudoGuiSummaryCounts {
    param(
        [Parameter(Mandatory)]
        [hashtable]$StatusMap
    )

    $counts = [ordered]@{
        Configured   = 0
        NeedsAction  = 0
        PendingReboot = 0
        Guidance     = 0
        Unsupported  = 0
        Errors       = 0
    }

    foreach ($status in $StatusMap.Values) {
        switch ($status.State) {
            'already-configured' { $counts.Configured += 1 }
            'needs-action' { $counts.NeedsAction += 1 }
            'pending-reboot' { $counts.PendingReboot += 1 }
            'advisory' { $counts.Guidance += 1 }
            'unsupported' { $counts.Unsupported += 1 }
            'error' { $counts.Errors += 1 }
        }
    }

    return [pscustomobject]$counts
}

function New-ScudoGuiComboItem {
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$Title
    )

    return [pscustomobject]@{
        Id    = $Id
        Title = $Title
    }
}

function Get-ScudoGuiComboItemId {
    param(
        [Parameter(Mandatory)]
        [object]$Item
    )

    if ($null -ne $Item -and $Item.GetType().FullName -eq 'System.Windows.Controls.ComboBoxItem') {
        return [string]$Item.Tag
    }

    if ($null -ne $Item.PSObject.Properties['Id']) {
        return [string]$Item.Id
    }

    return [string]$Item
}

function Get-ScudoGuiFilteredControls {
    param(
        [Parameter(Mandatory)]
        [array]$Controls,

        [string]$SectionId = 'all',
        [string]$TierFilter = 'all',
        [string]$SearchText
    )

    $needle = [string]$SearchText
    $needle = $needle.Trim().ToLowerInvariant()

    return @(
        $Controls | Where-Object {
            $control = $_

            if ($SectionId -ne 'all' -and $control.SectionId -ne $SectionId) {
                return $false
            }

            if ($TierFilter -ne 'all' -and $control.RecommendationTier -ne $TierFilter) {
                return $false
            }

            if ([string]::IsNullOrWhiteSpace($needle)) {
                return $true
            }

            $haystack = @(
                $control.Id
                $control.Title
                $control.Category
                $control.SectionId
                $control.WhatItDoes
                $control.WhyApply
                $control.WhyNotApply
                $control.RecommendationTier
                $control.AutomationLevel
            ) -join ' '

            return $haystack.ToLowerInvariant().Contains($needle)
        }
    )
}

function Get-ScudoGuiSchemaPath {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return Join-Path -Path $script:ScudoRoot -ChildPath ("gui/{0}" -f $Name)
}

function Import-ScudoGuiWindow {
    param(
        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    $xaml = Get-Content -Path $SchemaPath -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        return [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }
}

function Set-ScudoGuiResources {
    param(
        [Parameter(Mandatory)]
        [object]$Window
    )

    $theme = Get-ScudoGuiThemeDefinition
    foreach ($entry in $theme.GetEnumerator()) {
        $Window.Resources["$($entry.Key)Brush"] = Get-ScudoGuiBrush -Hex $entry.Value
    }
}

function Get-ScudoGuiPrimaryActionLabel {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control
    )

    if ($Control.Id -eq 'account.create-standard-user') {
        return 'Create user'
    }

    if ($Control.Kind -eq 'installable') {
        return 'Install'
    }

    if ($Control.Id -eq 'firmware.reboot-to-uefi') {
        return 'Reboot to firmware'
    }

    return 'Apply'
}

function Show-ScudoTextPrompt {
    param(
        [Parameter(Mandatory)]
        [object]$Owner,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Prompt,

        [switch]$AsPassword
    )

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    $window = Import-ScudoGuiWindow -SchemaPath (Get-ScudoGuiSchemaPath -Name 'scudo-prompt-window.xaml')
    Set-ScudoGuiResources -Window $window
    $window.Owner = $Owner
    $window.Title = $Title

    $titleText = $window.FindName('WindowTitleText')
    $titleBar = $window.FindName('TitleBarDragZone')
    $closeButton = $window.FindName('CloseButton')
    $promptText = $window.FindName('PromptText')
    $textInput = $window.FindName('TextInput')
    $passwordInput = $window.FindName('PasswordInput')
    $cancelButton = $window.FindName('CancelButton')
    $confirmButton = $window.FindName('ConfirmButton')

    $titleText.Text = $Title
    $promptText.Text = $Prompt

    if ($AsPassword) {
        $textInput.Visibility = [System.Windows.Visibility]::Collapsed
        $passwordInput.Visibility = [System.Windows.Visibility]::Visible
    }
    else {
        $textInput.Visibility = [System.Windows.Visibility]::Visible
        $passwordInput.Visibility = [System.Windows.Visibility]::Collapsed
    }

    $titleBar.Add_MouseLeftButtonDown({
        if ($_.ClickCount -ge 1) {
            $window.DragMove()
        }
    })

    $closeButton.Add_Click({
        $window.DialogResult = $false
        $window.Close()
    })

    $cancelButton.Add_Click({
        $window.DialogResult = $false
        $window.Close()
    })

    $confirmButton.Add_Click({
        $window.DialogResult = $true
        $window.Close()
    })

    $window.Add_ContentRendered({
        if ($AsPassword) {
            $passwordInput.Focus() | Out-Null
        }
        else {
            $textInput.Focus() | Out-Null
            $textInput.SelectAll()
        }
    })

    $accepted = $window.ShowDialog()
    if ($accepted -ne $true) {
        return $null
    }

    if ($AsPassword) {
        return $passwordInput.Password
    }

    return $textInput.Text
}

function Start-ScudoElevatedGui {
    if (-not (Test-ScudoWindows)) {
        return
    }

    $scriptPath = Join-Path -Path $script:ScudoRoot -ChildPath 'scudo.ps1'
    $argumentString = '-NoProfile -STA -ExecutionPolicy Bypass -File "{0}" --gui' -f $scriptPath
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argumentString | Out-Null
}

function Restart-ScudoGuiInSta {
    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA) {
        return $false
    }

    $scriptPath = Join-Path -Path $script:ScudoRoot -ChildPath 'scudo.ps1'
    $argumentString = '-NoProfile -STA -ExecutionPolicy Bypass -File "{0}" --gui' -f $scriptPath
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentString | Out-Null
    return $true
}

function Show-ScudoGui {
    if (-not (Test-ScudoWindows)) {
        throw 'The Scudo GUI only runs on Windows.'
    }

    if (Restart-ScudoGuiInSta) {
        return
    }

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms | Out-Null

    $window = Import-ScudoGuiWindow -SchemaPath (Get-ScudoGuiSchemaPath -Name 'scudo-main-window.xaml')
    Set-ScudoGuiResources -Window $window

    $titleBar = $window.FindName('TitleBarDragZone')
    $minimizeButton = $window.FindName('MinimizeButton')
    $closeButton = $window.FindName('CloseButton')
    $sessionBadge = $window.FindName('SessionBadge')
    $sessionBadgeText = $window.FindName('SessionBadgeText')

    $configuredCountText = $window.FindName('ConfiguredCountText')
    $needsActionCountText = $window.FindName('NeedsActionCountText')
    $rebootCountText = $window.FindName('RebootCountText')
    $guidanceCountText = $window.FindName('GuidanceCountText')

    $searchTextBox = $window.FindName('SearchTextBox')
    $sectionComboBox = $window.FindName('SectionComboBox')
    $trackComboBox = $window.FindName('TrackComboBox')
    $refreshStatusButton = $window.FindName('RefreshStatusButton')
    $exportReportButton = $window.FindName('ExportReportButton')
    $openReportsButton = $window.FindName('OpenReportsButton')
    $openCliButton = $window.FindName('OpenCliButton')

    $controlCountText = $window.FindName('ControlCountText')
    $controlListPanel = $window.FindName('ControlListPanel')
    $emptyStateText = $window.FindName('EmptyStateText')

    $detailTitleText = $window.FindName('DetailTitleText')
    $detailMetaText = $window.FindName('DetailMetaText')
    $detailStateBadge = $window.FindName('DetailStateBadge')
    $detailStateText = $window.FindName('DetailStateText')
    $detailSummaryText = $window.FindName('DetailSummaryText')
    $whatItDoesText = $window.FindName('WhatItDoesText')
    $whyApplyText = $window.FindName('WhyApplyText')
    $whySkipText = $window.FindName('WhySkipText')
    $rollbackNoteText = $window.FindName('RollbackNoteText')
    $statusNotesText = $window.FindName('StatusNotesText')

    $refreshSelectedButton = $window.FindName('RefreshSelectedButton')
    $applyButton = $window.FindName('ApplyButton')
    $rollbackButton = $window.FindName('RollbackButton')
    $statusBarText = $window.FindName('StatusBarText')

    $controls = @(Get-ScudoSortedControls)
    $sectionMap = Get-ScudoGuiSectionMap
    $guiState = @{
        SelectedControlId = $null
        StatusMap         = @{}
        CardMap           = @{}
        SectionId         = 'all'
        TierFilter        = 'all'
        SearchText        = ''
    }

    $setBusy = {
        param([bool]$IsBusy)

        if ($IsBusy) {
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
        }
        else {
            [System.Windows.Input.Mouse]::OverrideCursor = $null
        }
    }

    $setStatusBar = {
        param([string]$Text)
        $statusBarText.Text = $Text
    }

    $showMessage = {
        param(
            [string]$Message,
            [string]$Title = 'scudo',
            [System.Windows.MessageBoxButton]$Button = [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
        )

        return [System.Windows.MessageBox]::Show($window, $Message, $Title, $Button, $Icon)
    }

    $applyCardStyle = {
        param(
            [hashtable]$CardRef,
            [bool]$IsSelected
        )

        if ($IsSelected) {
            $CardRef.Border.Background = $window.Resources['BgSurfaceSelectedBrush']
            $CardRef.Border.BorderBrush = $window.Resources['BorderStrongBrush']
            $CardRef.Title.Foreground = $window.Resources['TextPrimaryBrush']
            $CardRef.Meta.Foreground = $window.Resources['TextPrimaryBrush']
        }
        else {
            $CardRef.Border.Background = [System.Windows.Media.Brushes]::Transparent
            $CardRef.Border.BorderBrush = $window.Resources['BorderBrush']
            $CardRef.Title.Foreground = $window.Resources['TextPrimaryBrush']
            $CardRef.Meta.Foreground = $window.Resources['TextMutedBrush']
        }
    }

    $renderDetails = {
        if ([string]::IsNullOrWhiteSpace($guiState.SelectedControlId)) {
            $detailTitleText.Text = 'Select a control'
            $detailMetaText.Text = 'Search or filter on the left, then inspect the control here.'
            $detailStateText.Text = 'No selection'
            $detailStateBadge.Background = $window.Resources['StatusUnsupportedBrush']
            $detailSummaryText.Text = 'Scudo keeps the hardening rationale visible before you apply anything.'
            $whatItDoesText.Text = ''
            $whyApplyText.Text = ''
            $whySkipText.Text = ''
            $rollbackNoteText.Text = ''
            $statusNotesText.Text = ''
            $refreshSelectedButton.IsEnabled = $false
            $applyButton.IsEnabled = $false
            $rollbackButton.IsEnabled = $false
            $applyButton.Content = 'Apply'
            return
        }

        $control = $controls | Where-Object { $_.Id -eq $guiState.SelectedControlId } | Select-Object -First 1
        $status = $guiState.StatusMap[$guiState.SelectedControlId]
        $snapshot = if ($null -ne $control) { Get-ScudoControlSnapshot -ControlId $control.Id } else { $null }
        if ($null -eq $control -or $null -eq $status) {
            return
        }

        $section = $sectionMap[$control.SectionId]
        $sectionTitle = if ($null -ne $section) { $section.Title } else { $control.SectionId }
        $detailTitleText.Text = $control.Title
        $detailMetaText.Text = ('{0} / {1} / {2} / {3}' -f $sectionTitle, $control.Category, (Get-ScudoGuiTierLabel -Tier $control.RecommendationTier), (Get-ScudoGuiAutomationLabel -AutomationLevel $control.AutomationLevel))
        $detailStateText.Text = Get-ScudoGuiStateLabel -Status $status
        $detailStateBadge.Background = $window.Resources[(Get-ScudoGuiStatusResourceKey -Status $status)]
        $detailSummaryText.Text = $status.Summary
        $whatItDoesText.Text = $control.WhatItDoes
        $whyApplyText.Text = $control.WhyApply
        $whySkipText.Text = $control.WhyNotApply
        $rollbackNoteText.Text = $control.RollbackNote

        $statusNotes = @(
            @($status.Notes) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        if (@($statusNotes).Count -gt 0) {
            $statusNotesText.Text = ($statusNotes | ForEach-Object { '- {0}' -f $_ }) -join [Environment]::NewLine
        }
        else {
            $statusNotesText.Text = 'No extra notes.'
        }

        $refreshSelectedButton.IsEnabled = $true
        $applyButton.IsEnabled = $control.Kind -in @('applyable', 'installable', 'special')
        $applyButton.Content = Get-ScudoGuiPrimaryActionLabel -Control $control
        $rollbackButton.IsEnabled = (Test-ScudoControlRollbackSupported -Control $control) -and $null -ne $snapshot
    }

    $selectControl = {
        param([string]$ControlId)

        $guiState.SelectedControlId = $ControlId
        foreach ($entry in $guiState.CardMap.GetEnumerator()) {
            & $applyCardStyle $entry.Value ($entry.Key -eq $ControlId)
        }

        & $renderDetails
    }

    $newControlCard = {
        param(
            [pscustomobject]$Control,
            [pscustomobject]$Status
        )

        $button = New-Object System.Windows.Controls.Button
        $button.Style = $window.Resources['ControlRowButtonStyle']
        $button.Tag = $Control.Id

        $border = New-Object System.Windows.Controls.Border
        $border.CornerRadius = [System.Windows.CornerRadius]::new(0)
        $border.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
        $border.Padding = [System.Windows.Thickness]::new(14, 0, 14, 0)
        $border.Margin = [System.Windows.Thickness]::new(0, 0, 0, -1)
        $border.Height = 44
        $border.Background = [System.Windows.Media.Brushes]::Transparent
        $border.BorderBrush = $window.Resources['BorderBrush']

        $grid = New-Object System.Windows.Controls.Grid
        $null = $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) }))
        $null = $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))

        $contentStack = New-Object System.Windows.Controls.StackPanel
        $contentStack.Orientation = [System.Windows.Controls.Orientation]::Vertical
        $contentStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($contentStack, 0)

        $title = New-Object System.Windows.Controls.TextBlock
        $title.Text = $Control.Title
        $title.FontSize = 13
        $title.FontWeight = [System.Windows.FontWeights]::SemiBold
        $title.Foreground = $window.Resources['TextPrimaryBrush']
        $title.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

        $section = $sectionMap[$Control.SectionId]
        $sectionTitle = if ($null -ne $section) { $section.Title } else { $Control.SectionId }

        $meta = New-Object System.Windows.Controls.TextBlock
        $meta.Text = ('{0} / {1}' -f $sectionTitle, (Get-ScudoGuiTierLabel -Tier $Control.RecommendationTier))
        $meta.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
        $meta.FontSize = 10.5
        $meta.Foreground = $window.Resources['TextMutedBrush']
        $meta.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

        $statusBadge = New-Object System.Windows.Controls.Border
        $statusBadge.Background = $window.Resources[(Get-ScudoGuiStatusResourceKey -Status $Status)]
        $statusBadge.CornerRadius = [System.Windows.CornerRadius]::new(2)
        $statusBadge.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
        $statusBadge.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        $statusBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($statusBadge, 1)

        $statusText = New-Object System.Windows.Controls.TextBlock
        $statusText.Text = Get-ScudoGuiStatusText -Status $Status
        $statusText.FontSize = 10
        $statusText.FontWeight = [System.Windows.FontWeights]::Bold
        $statusText.Foreground = if ($Status.State -in @('already-configured', 'needs-action', 'pending-reboot', 'advisory')) {
            $window.Resources['BgMainBrush']
        }
        else {
            $window.Resources['TextPrimaryBrush']
        }
        $statusBadge.Child = $statusText

        $contentStack.Children.Add($title) | Out-Null
        $contentStack.Children.Add($meta) | Out-Null

        $grid.Children.Add($contentStack) | Out-Null
        $grid.Children.Add($statusBadge) | Out-Null
        $border.Child = $grid
        $button.Content = $border

        $button.Add_Click({
            param($sender, $args)
            & $selectControl $sender.Tag
        })

        return @{
            Button     = $button
            Border     = $border
            Title      = $title
            Meta       = $meta
            StatusBadge = $statusBadge
            StatusText = $statusText
        }
    }

    $renderSummary = {
        $counts = Get-ScudoGuiSummaryCounts -StatusMap $guiState.StatusMap
        $configuredCountText.Text = [string]$counts.Configured
        $needsActionCountText.Text = [string]$counts.NeedsAction
        $rebootCountText.Text = [string]$counts.PendingReboot
        $guidanceCountText.Text = [string]$counts.Guidance
    }

    $renderControlList = {
        $visibleControls = Get-ScudoGuiFilteredControls -Controls $controls -SectionId $guiState.SectionId -TierFilter $guiState.TierFilter -SearchText $guiState.SearchText
        $controlListPanel.Children.Clear()
        $guiState.CardMap = @{}

        $controlCountText.Text = ('{0} controls' -f @($visibleControls).Count)
        $emptyStateText.Visibility = if (@($visibleControls).Count -eq 0) {
            [System.Windows.Visibility]::Visible
        }
        else {
            [System.Windows.Visibility]::Collapsed
        }

        foreach ($control in $visibleControls) {
            $card = & $newControlCard $control $guiState.StatusMap[$control.Id]
            $controlListPanel.Children.Add($card.Button) | Out-Null
            $guiState.CardMap[$control.Id] = $card
        }

        if (@($visibleControls).Count -eq 0) {
            $guiState.SelectedControlId = $null
            & $renderDetails
            return
        }

        if ([string]::IsNullOrWhiteSpace($guiState.SelectedControlId) -or -not $guiState.CardMap.ContainsKey($guiState.SelectedControlId)) {
            $guiState.SelectedControlId = $visibleControls[0].Id
        }

        & $selectControl $guiState.SelectedControlId
    }

    $refreshAll = {
        & $setStatusBar 'Refreshing control state...'
        & $setBusy $true
        try {
            $guiState.StatusMap = Get-ScudoStatusMap
            & $renderSummary
            & $renderControlList
            & $setStatusBar ('Loaded {0} controls.' -f $controls.Count)
        }
        finally {
            & $setBusy $false
        }
    }

    $refreshSelected = {
        if ([string]::IsNullOrWhiteSpace($guiState.SelectedControlId)) {
            return
        }

        $control = $controls | Where-Object { $_.Id -eq $guiState.SelectedControlId } | Select-Object -First 1
        if ($null -eq $control) {
            return
        }

        & $setStatusBar ('Refreshing {0}...' -f $control.Title)
        & $setBusy $true
        try {
            $guiState.StatusMap[$control.Id] = Invoke-ScudoControlDetection -Control $control
            & $renderSummary
            & $renderControlList
            & $setStatusBar ('Refreshed {0}.' -f $control.Title)
        }
        finally {
            & $setBusy $false
        }
    }

    $exportReports = {
        & $setStatusBar 'Exporting report...'
        try {
            $paths = Export-ScudoReport -Results (Get-ScudoReportEntries)
            & $showMessage ("Markdown:`n{0}`n`nJSON:`n{1}" -f $paths.MarkdownPath, $paths.JsonPath) 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Information) | Out-Null
            & $setStatusBar ('Exported report to {0}' -f $paths.MarkdownPath)
        }
        catch {
            & $showMessage $_.Exception.Message 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Error) | Out-Null
            & $setStatusBar 'Report export failed.'
        }
    }

    $openReports = {
        $reportDirectory = Get-ScudoReportDirectory
        New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null
        Start-Process -FilePath 'explorer.exe' -ArgumentList $reportDirectory | Out-Null
        & $setStatusBar ('Opened {0}' -f $reportDirectory)
    }

    $openCli = {
        $scriptPath = Join-Path -Path $script:ScudoRoot -ChildPath 'scudo.ps1'
        Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}" --cli' -f $scriptPath) | Out-Null
        & $setStatusBar 'Opened a CLI session.'
    }

    $runApply = {
        if ([string]::IsNullOrWhiteSpace($guiState.SelectedControlId)) {
            return
        }

        $control = $controls | Where-Object { $_.Id -eq $guiState.SelectedControlId } | Select-Object -First 1
        $status = $guiState.StatusMap[$guiState.SelectedControlId]
        if ($null -eq $control -or $null -eq $status) {
            return
        }

        if ($control.RequiresAdmin -and -not (Test-ScudoAdministrator)) {
            $elevate = & $showMessage 'This action needs administrator rights. Relaunch the GUI elevated now?' 'scudo' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Question)
            if ($elevate -eq [System.Windows.MessageBoxResult]::Yes) {
                Start-ScudoElevatedGui
                $window.Close()
            }
            return
        }

        if ($control.Id -eq 'account.create-standard-user') {
            $userName = Show-ScudoTextPrompt -Owner $window -Title 'Create standard user' -Prompt 'Enter the new local username'
            if ([string]::IsNullOrWhiteSpace($userName)) {
                return
            }

            $passwordText = Show-ScudoTextPrompt -Owner $window -Title 'Create standard user' -Prompt 'Enter the password for the new account' -AsPassword
            if ($null -eq $passwordText) {
                return
            }

            $securePassword = ConvertTo-SecureString -String $passwordText -AsPlainText -Force
            & $setBusy $true
            try {
                $result = New-ScudoStandardUser -UserName $userName -Password $securePassword
                & $showMessage $result.Summary 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Information) | Out-Null
            }
            finally {
                & $setBusy $false
            }

            & $refreshAll
            & $selectControl $control.Id
            return
        }

        $preflight = Get-ScudoPreflightStatus -Control $control -Action 'apply'
        if ($preflight.Blocked) {
            $message = @($preflight.Summary) + @($preflight.Notes)
            & $showMessage ($message -join [Environment]::NewLine) 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        $confirm = & $showMessage ("Apply '{0}' now?" -f $control.Title) 'scudo' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
            return
        }

        & $setStatusBar ('Applying {0}...' -f $control.Title)
        & $setBusy $true
        try {
            $result = Invoke-ScudoControlApply -Control $control
            Save-ScudoOperationState -Control $control -Action 'apply' -BeforeStatus $status -ResultStatus $result | Out-Null
            & $showMessage $result.Summary 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Information) | Out-Null
        }
        catch {
            & $showMessage $_.Exception.Message 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Error) | Out-Null
        }
        finally {
            & $setBusy $false
        }

        & $refreshAll
        & $selectControl $control.Id
    }

    $runRollback = {
        if ([string]::IsNullOrWhiteSpace($guiState.SelectedControlId)) {
            return
        }

        $control = $controls | Where-Object { $_.Id -eq $guiState.SelectedControlId } | Select-Object -First 1
        $snapshot = Get-ScudoControlSnapshot -ControlId $guiState.SelectedControlId
        if ($null -eq $control -or $null -eq $snapshot) {
            return
        }

        if (-not (Test-ScudoAdministrator)) {
            $elevate = & $showMessage 'This action needs administrator rights. Relaunch the GUI elevated now?' 'scudo' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Question)
            if ($elevate -eq [System.Windows.MessageBoxResult]::Yes) {
                Start-ScudoElevatedGui
                $window.Close()
            }
            return
        }

        $preflight = Get-ScudoPreflightStatus -Control $control -Action 'rollback'
        if ($preflight.Blocked) {
            $message = @($preflight.Summary) + @($preflight.Notes)
            & $showMessage ($message -join [Environment]::NewLine) 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        $confirm = & $showMessage ("Restore the saved state for '{0}' now?" -f $control.Title) 'scudo' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
            return
        }

        & $setStatusBar ('Rolling back {0}...' -f $control.Title)
        & $setBusy $true
        try {
            $currentStatus = Invoke-ScudoControlDetection -Control $control
            $result = Invoke-ScudoControlRollback -Control $control -Snapshot $snapshot
            Save-ScudoOperationState -Control $control -Action 'rollback' -BeforeStatus $currentStatus -ResultStatus $result | Out-Null
            & $showMessage $result.Summary 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Information) | Out-Null
        }
        catch {
            & $showMessage $_.Exception.Message 'scudo' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Error) | Out-Null
        }
        finally {
            & $setBusy $false
        }

        & $refreshAll
        & $selectControl $control.Id
    }

    $titleBar.Add_MouseLeftButtonDown({
        if ($_.ClickCount -eq 2) {
            if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
                $window.WindowState = [System.Windows.WindowState]::Normal
            }
            else {
                $window.WindowState = [System.Windows.WindowState]::Maximized
            }
            return
        }

        $window.DragMove()
    })

    $minimizeButton.Add_Click({
        $window.WindowState = [System.Windows.WindowState]::Minimized
    })

    $closeButton.Add_Click({
        $window.Close()
    })

    $sectionChoices = @(
        (New-ScudoGuiComboItem -Id 'all' -Title 'All sections')
    ) + @(
        Get-ScudoSectionCatalog |
            Sort-Object DisplayRank |
            ForEach-Object {
                New-ScudoGuiComboItem -Id $_.Id -Title $_.Title
            }
    )
    $sectionComboBox.ItemsSource = $sectionChoices
    $sectionComboBox.SelectedIndex = 0

    $trackChoices = @(
        (New-ScudoGuiComboItem -Id 'all' -Title 'All tracks')
        (New-ScudoGuiComboItem -Id 'baseline' -Title 'Baseline')
        (New-ScudoGuiComboItem -Id 'strict' -Title 'Strict')
        (New-ScudoGuiComboItem -Id 'guided' -Title 'Guided')
        (New-ScudoGuiComboItem -Id 'optional' -Title 'Optional apps')
    )
    $trackComboBox.ItemsSource = $trackChoices
    $trackComboBox.SelectedIndex = 0

    if (Test-ScudoAdministrator) {
        $sessionBadgeText.Text = 'Elevated session'
        $sessionBadge.Background = $window.Resources['AccentPrimaryBrush']
        $sessionBadge.BorderThickness = [System.Windows.Thickness]::new(0)
        $sessionBadgeText.Foreground = $window.Resources['BgMainBrush']
    }
    else {
        $sessionBadgeText.Text = 'Standard session'
        $sessionBadge.Background = $window.Resources['BgSurfaceBrush']
        $sessionBadge.BorderBrush = $window.Resources['BorderBrush']
        $sessionBadge.BorderThickness = [System.Windows.Thickness]::new(1)
        $sessionBadgeText.Foreground = $window.Resources['TextPrimaryBrush']
    }

    $searchTextBox.Add_TextChanged({
        $guiState.SearchText = [string]$searchTextBox.Text
        & $renderControlList
    })

    $sectionComboBox.Add_SelectionChanged({
        if ($null -ne $sectionComboBox.SelectedItem) {
            $guiState.SectionId = Get-ScudoGuiComboItemId -Item $sectionComboBox.SelectedItem
            & $renderControlList
        }
    })

    $trackComboBox.Add_SelectionChanged({
        if ($null -ne $trackComboBox.SelectedItem) {
            $guiState.TierFilter = Get-ScudoGuiComboItemId -Item $trackComboBox.SelectedItem
            & $renderControlList
        }
    })

    $refreshStatusButton.Add_Click({ & $refreshAll })
    $refreshSelectedButton.Add_Click({ & $refreshSelected })
    $applyButton.Add_Click({ & $runApply })
    $rollbackButton.Add_Click({ & $runRollback })
    $exportReportButton.Add_Click({ & $exportReports })
    $openReportsButton.Add_Click({ & $openReports })
    $openCliButton.Add_Click({ & $openCli })

    & $refreshAll
    [void]$window.ShowDialog()
}
