Set-StrictMode -Version Latest

function Get-ScudoGuiColor {
    param(
        [Parameter(Mandatory)]
        [string]$Hex
    )

    return [System.Drawing.ColorTranslator]::FromHtml("#$Hex")
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

function Get-ScudoGuiStatusColor {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Status,

        [Parameter(Mandatory)]
        [hashtable]$Palette
    )

    switch ($Status.State) {
        'already-configured' { return $Palette.Success }
        'needs-action' { return $Palette.Accent }
        'pending-reboot' { return $Palette.Accent }
        'advisory' { return $Palette.Accent }
        'unsupported' { return $Palette.Muted }
        'error' { return $Palette.Danger }
        default { return $Palette.Accent }
    }
}

function Set-ScudoGuiButtonStyle {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Button]$Button,

        [Parameter(Mandatory)]
        [System.Drawing.Color]$BackColor,

        [Parameter(Mandatory)]
        [System.Drawing.Color]$ForeColor
    )

    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 0
    $Button.BackColor = $BackColor
    $Button.ForeColor = $ForeColor
    $Button.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
}

function New-ScudoGuiLabel {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$X,

        [Parameter(Mandatory)]
        [int]$Y,

        [Parameter(Mandatory)]
        [int]$Width,

        [Parameter(Mandatory)]
        [int]$Height,

        [System.Drawing.Color]$ForeColor,
        [float]$Size = 9,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.ForeColor = $ForeColor
    $label.Font = New-Object System.Drawing.Font('Segoe UI', $Size, $Style)
    return $label
}

function Show-ScudoTextPrompt {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Form]$Owner,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [hashtable]$Palette,

        [switch]$AsPassword
    )

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.ClientSize = New-Object System.Drawing.Size(420, 160)
    $dialog.BackColor = $Palette.Base
    $dialog.ForeColor = $Palette.Accent
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false

    $promptLabel = New-ScudoGuiLabel -Text $Prompt -X 20 -Y 18 -Width 380 -Height 24 -ForeColor $Palette.Accent
    $dialog.Controls.Add($promptLabel)

    $inputBox = New-Object System.Windows.Forms.TextBox
    $inputBox.Location = New-Object System.Drawing.Point(20, 54)
    $inputBox.Size = New-Object System.Drawing.Size(380, 26)
    $inputBox.BackColor = (Get-ScudoGuiColor -Hex '2B3031')
    $inputBox.ForeColor = $Palette.Accent
    $inputBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    if ($AsPassword) {
        $inputBox.UseSystemPasswordChar = $true
    }
    $dialog.Controls.Add($inputBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'OK'
    $okButton.Location = New-Object System.Drawing.Point(220, 108)
    $okButton.Size = New-Object System.Drawing.Size(84, 32)
    Set-ScudoGuiButtonStyle -Button $okButton -BackColor $Palette.Success -ForeColor $Palette.Base
    $okButton.Add_Click({
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })
    $dialog.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Location = New-Object System.Drawing.Point(316, 108)
    $cancelButton.Size = New-Object System.Drawing.Size(84, 32)
    Set-ScudoGuiButtonStyle -Button $cancelButton -BackColor (Get-ScudoGuiColor -Hex '2B3031') -ForeColor $Palette.Accent
    $cancelButton.Add_Click({
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $dialog.Close()
    })
    $dialog.Controls.Add($cancelButton)

    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton

    if ($dialog.ShowDialog($Owner) -eq [System.Windows.Forms.DialogResult]::OK) {
        return $inputBox.Text
    }

    return $null
}

function Start-ScudoElevatedGui {
    if (-not (Test-ScudoWindows)) {
        return
    }

    $scriptPath = Join-Path -Path $script:ScudoRoot -ChildPath 'scudo.ps1'
    $argumentString = '-NoProfile -ExecutionPolicy Bypass -File "{0}" --gui' -f $scriptPath
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argumentString | Out-Null
}

function Show-ScudoGui {
    if (-not (Test-ScudoWindows)) {
        throw 'The Scudo GUI only runs on Windows.'
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $palette = @{
        Base    = Get-ScudoGuiColor -Hex '353A3B'
        Success = Get-ScudoGuiColor -Hex '77AA77'
        Accent  = Get-ScudoGuiColor -Hex 'F4E3C1'
        Danger  = Get-ScudoGuiColor -Hex 'C52713'
        Surface = Get-ScudoGuiColor -Hex '2B3031'
        Muted   = Get-ScudoGuiColor -Hex '9B927D'
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'scudo'
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.ClientSize = New-Object System.Drawing.Size(1320, 820)
    $form.MinimumSize = New-Object System.Drawing.Size(1180, 760)
    $form.BackColor = $palette.Base
    $form.ForeColor = $palette.Accent
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object System.Drawing.Point(24, 20)
    $header.Size = New-Object System.Drawing.Size(1272, 72)
    $header.BackColor = $palette.Base
    $form.Controls.Add($header)

    $titleLabel = New-ScudoGuiLabel -Text 'scudo' -X 0 -Y 0 -Width 300 -Height 30 -ForeColor $palette.Accent -Size 22 -Style Bold
    $subtitleLabel = New-ScudoGuiLabel -Text 'Windows 11 hardening. One control at a time.' -X 2 -Y 36 -Width 420 -Height 22 -ForeColor $palette.Muted -Size 9.5
    $header.Controls.Add($titleLabel)
    $header.Controls.Add($subtitleLabel)

    $sessionLabel = New-ScudoGuiLabel -Text '' -X 950 -Y 10 -Width 300 -Height 24 -ForeColor $palette.Muted -Size 9
    $header.Controls.Add($sessionLabel)

    $toolbar = New-Object System.Windows.Forms.Panel
    $toolbar.Location = New-Object System.Drawing.Point(24, 96)
    $toolbar.Size = New-Object System.Drawing.Size(1272, 56)
    $toolbar.BackColor = $palette.Base
    $form.Controls.Add($toolbar)

    $categoryBox = New-Object System.Windows.Forms.ComboBox
    $categoryBox.Location = New-Object System.Drawing.Point(0, 12)
    $categoryBox.Size = New-Object System.Drawing.Size(220, 28)
    $categoryBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $categoryBox.BackColor = $palette.Surface
    $categoryBox.ForeColor = $palette.Accent
    $toolbar.Controls.Add($categoryBox)

    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Text = 'Refresh Status'
    $refreshButton.Location = New-Object System.Drawing.Point(240, 10)
    $refreshButton.Size = New-Object System.Drawing.Size(140, 34)
    Set-ScudoGuiButtonStyle -Button $refreshButton -BackColor $palette.Accent -ForeColor $palette.Base
    $toolbar.Controls.Add($refreshButton)

    $exportButton = New-Object System.Windows.Forms.Button
    $exportButton.Text = 'Export Report'
    $exportButton.Location = New-Object System.Drawing.Point(392, 10)
    $exportButton.Size = New-Object System.Drawing.Size(140, 34)
    Set-ScudoGuiButtonStyle -Button $exportButton -BackColor $palette.Surface -ForeColor $palette.Accent
    $toolbar.Controls.Add($exportButton)

    $openReportsButton = New-Object System.Windows.Forms.Button
    $openReportsButton.Text = 'Open Reports'
    $openReportsButton.Location = New-Object System.Drawing.Point(544, 10)
    $openReportsButton.Size = New-Object System.Drawing.Size(140, 34)
    Set-ScudoGuiButtonStyle -Button $openReportsButton -BackColor $palette.Surface -ForeColor $palette.Accent
    $toolbar.Controls.Add($openReportsButton)

    $cliButton = New-Object System.Windows.Forms.Button
    $cliButton.Text = 'Open CLI'
    $cliButton.Location = New-Object System.Drawing.Point(696, 10)
    $cliButton.Size = New-Object System.Drawing.Size(120, 34)
    Set-ScudoGuiButtonStyle -Button $cliButton -BackColor $palette.Surface -ForeColor $palette.Accent
    $toolbar.Controls.Add($cliButton)

    $cardsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $cardsPanel.Location = New-Object System.Drawing.Point(24, 168)
    $cardsPanel.Size = New-Object System.Drawing.Size(820, 620)
    $cardsPanel.WrapContents = $false
    $cardsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $cardsPanel.AutoScroll = $true
    $cardsPanel.BackColor = $palette.Base
    $form.Controls.Add($cardsPanel)

    $detailsPanel = New-Object System.Windows.Forms.Panel
    $detailsPanel.Location = New-Object System.Drawing.Point(870, 168)
    $detailsPanel.Size = New-Object System.Drawing.Size(426, 620)
    $detailsPanel.BackColor = $palette.Surface
    $detailsPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $form.Controls.Add($detailsPanel)

    $detailTitle = New-ScudoGuiLabel -Text 'Select a control' -X 18 -Y 18 -Width 380 -Height 30 -ForeColor $palette.Accent -Size 18 -Style Bold
    $detailMeta = New-ScudoGuiLabel -Text '' -X 20 -Y 54 -Width 380 -Height 22 -ForeColor $palette.Muted -Size 9
    $detailState = New-ScudoGuiLabel -Text '' -X 20 -Y 84 -Width 380 -Height 24 -ForeColor $palette.Accent -Size 10 -Style Bold
    $detailSummary = New-ScudoGuiLabel -Text '' -X 20 -Y 116 -Width 380 -Height 58 -ForeColor $palette.Accent -Size 9.5
    $detailSummary.MaximumSize = New-Object System.Drawing.Size(380, 0)
    $detailSummary.AutoSize = $true
    $detailsPanel.Controls.Add($detailTitle)
    $detailsPanel.Controls.Add($detailMeta)
    $detailsPanel.Controls.Add($detailState)
    $detailsPanel.Controls.Add($detailSummary)

    $guidanceHeading = New-ScudoGuiLabel -Text 'What it does / why apply' -X 20 -Y 200 -Width 240 -Height 22 -ForeColor $palette.Muted -Size 9 -Style Bold
    $detailsPanel.Controls.Add($guidanceHeading)

    $guidanceBox = New-Object System.Windows.Forms.TextBox
    $guidanceBox.Location = New-Object System.Drawing.Point(20, 226)
    $guidanceBox.Size = New-Object System.Drawing.Size(380, 136)
    $guidanceBox.Multiline = $true
    $guidanceBox.ReadOnly = $true
    $guidanceBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $guidanceBox.BackColor = $palette.Base
    $guidanceBox.ForeColor = $palette.Accent
    $guidanceBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $detailsPanel.Controls.Add($guidanceBox)

    $notesHeading = New-ScudoGuiLabel -Text 'Why skip / rollback' -X 20 -Y 380 -Width 220 -Height 22 -ForeColor $palette.Muted -Size 9 -Style Bold
    $detailsPanel.Controls.Add($notesHeading)

    $notesBox = New-Object System.Windows.Forms.TextBox
    $notesBox.Location = New-Object System.Drawing.Point(20, 406)
    $notesBox.Size = New-Object System.Drawing.Size(380, 108)
    $notesBox.Multiline = $true
    $notesBox.ReadOnly = $true
    $notesBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $notesBox.BackColor = $palette.Base
    $notesBox.ForeColor = $palette.Accent
    $notesBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $detailsPanel.Controls.Add($notesBox)

    $refreshSelectedButton = New-Object System.Windows.Forms.Button
    $refreshSelectedButton.Text = 'Refresh'
    $refreshSelectedButton.Location = New-Object System.Drawing.Point(20, 546)
    $refreshSelectedButton.Size = New-Object System.Drawing.Size(116, 40)
    Set-ScudoGuiButtonStyle -Button $refreshSelectedButton -BackColor $palette.Accent -ForeColor $palette.Base
    $detailsPanel.Controls.Add($refreshSelectedButton)

    $applyButton = New-Object System.Windows.Forms.Button
    $applyButton.Text = 'Apply'
    $applyButton.Location = New-Object System.Drawing.Point(152, 546)
    $applyButton.Size = New-Object System.Drawing.Size(116, 40)
    Set-ScudoGuiButtonStyle -Button $applyButton -BackColor $palette.Success -ForeColor $palette.Base
    $detailsPanel.Controls.Add($applyButton)

    $rollbackButton = New-Object System.Windows.Forms.Button
    $rollbackButton.Text = 'Rollback'
    $rollbackButton.Location = New-Object System.Drawing.Point(284, 546)
    $rollbackButton.Size = New-Object System.Drawing.Size(116, 40)
    Set-ScudoGuiButtonStyle -Button $rollbackButton -BackColor $palette.Danger -ForeColor $palette.Accent
    $detailsPanel.Controls.Add($rollbackButton)

    $footerLabel = New-ScudoGuiLabel -Text 'Ready.' -X 24 -Y 794 -Width 1272 -Height 20 -ForeColor $palette.Muted -Size 9
    $form.Controls.Add($footerLabel)

    $controls = @(Get-ScudoSortedControls)
    $guiState = @{
        SelectedControlId = $null
        StatusMap         = @{}
        CardMap           = @{}
    }

    $renderDetails = {
        if ([string]::IsNullOrWhiteSpace($guiState.SelectedControlId)) {
            $detailTitle.Text = 'Select a control'
            $detailMeta.Text = ''
            $detailState.Text = ''
            $detailSummary.Text = ''
            $guidanceBox.Text = ''
            $notesBox.Text = ''
            $applyButton.Enabled = $false
            $rollbackButton.Enabled = $false
            $refreshSelectedButton.Enabled = $false
            return
        }

        $control = $controls | Where-Object { $_.Id -eq $guiState.SelectedControlId } | Select-Object -First 1
        $status = $guiState.StatusMap[$guiState.SelectedControlId]
        $snapshot = if ($null -ne $control) { Get-ScudoControlSnapshot -ControlId $control.Id } else { $null }

        $detailTitle.Text = $control.Title
        $detailMeta.Text = ('{0}  |  tier: {1}  |  {2}' -f $control.Category, $control.RecommendationTier, $control.AutomationLevel)
        $detailState.Text = ('State: {0}' -f $status.Summary)
        $detailState.ForeColor = Get-ScudoGuiStatusColor -Status $status -Palette $palette
        $detailSummary.Text = $status.Summary
        $guidanceBox.Text = @(
            "What it does:"
            $control.WhatItDoes
            ''
            "Why apply it:"
            $control.WhyApply
        ) -join [Environment]::NewLine
        $statusNotes = @(
            @($status.Notes) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $notesLines = New-Object System.Collections.Generic.List[string]
        $notesLines.Add('Why skip it:')
        $notesLines.Add($control.WhyNotApply)
        $notesLines.Add('')
        $notesLines.Add(('Rollback: {0}' -f $control.RollbackNote))
        $notesLines.Add(('Admin: {0}' -f $control.RequiresAdmin))
        $notesLines.Add(('Reboot: {0}' -f $control.RequiresReboot))
        if (@($statusNotes).Count -gt 0) {
            $notesLines.Add('')
            $notesLines.Add('Status notes:')
            foreach ($note in $statusNotes) {
                $notesLines.Add("- $note")
            }
        }
        $notesBox.Text = $notesLines -join [Environment]::NewLine
        $refreshSelectedButton.Enabled = $true

        $applyButton.Enabled = $control.Kind -in @('applyable', 'installable', 'special')
        $applyButton.Text = if ($control.Id -eq 'account.create-standard-user') { 'Create User' } elseif ($control.Kind -eq 'installable') { 'Install' } else { 'Apply' }

        $rollbackButton.Enabled = (Test-ScudoControlRollbackSupported -Control $control) -and $null -ne $snapshot
    }

    $selectControl = {
        param([string]$ControlId)

        $guiState.SelectedControlId = $ControlId
        foreach ($entry in $guiState.CardMap.GetEnumerator()) {
            $panel = $entry.Value.Panel
            $title = $entry.Value.Title
            $meta = $entry.Value.Meta
            $summary = $entry.Value.Summary
            if ($entry.Key -eq $guiState.SelectedControlId) {
                $panel.BackColor = $palette.Accent
                $title.ForeColor = $palette.Base
                $meta.ForeColor = $palette.Base
                $summary.ForeColor = $palette.Base
            }
            else {
                $panel.BackColor = $palette.Surface
                $title.ForeColor = $palette.Accent
                $meta.ForeColor = $palette.Muted
                $summary.ForeColor = $palette.Accent
            }
        }

        & $renderDetails
    }

    $refreshList = {
        $footerLabel.Text = 'Refreshing control state...'
        $form.UseWaitCursor = $true
        try {
            $guiState.StatusMap = Get-ScudoStatusMap
            $selectedCategory = [string]$categoryBox.SelectedItem
            $cardsPanel.SuspendLayout()
            $cardsPanel.Controls.Clear()
            $guiState.CardMap = @{}

            $visibleControls = @(
                $controls | Where-Object {
                    $selectedCategory -eq 'All categories' -or $_.Category -eq $selectedCategory
                }
            )

            foreach ($control in $visibleControls) {
                $status = $guiState.StatusMap[$control.Id]
                $card = New-Object System.Windows.Forms.Panel
                $card.Size = New-Object System.Drawing.Size(780, 82)
                $card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
                $card.BackColor = $palette.Surface
                $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
                $card.Cursor = [System.Windows.Forms.Cursors]::Hand

                $badge = New-Object System.Windows.Forms.Label
                $badge.Text = Get-ScudoGuiStatusText -Status $status
                $badge.Location = New-Object System.Drawing.Point(16, 16)
                $badge.Size = New-Object System.Drawing.Size(88, 26)
                $badge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
                $badge.BackColor = Get-ScudoGuiStatusColor -Status $status -Palette $palette
                $badge.ForeColor = $palette.Base
                $badge.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

                $title = New-Object System.Windows.Forms.Label
                $title.Text = $control.Title
                $title.Location = New-Object System.Drawing.Point(122, 12)
                $title.Size = New-Object System.Drawing.Size(620, 24)
                $title.ForeColor = $palette.Accent
                $title.Font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)

                $meta = New-Object System.Windows.Forms.Label
                $meta.Text = ('{0}  |  {1}  |  {2}' -f $control.Category, $control.RecommendationTier, $control.AutomationLevel)
                $meta.Location = New-Object System.Drawing.Point(122, 38)
                $meta.Size = New-Object System.Drawing.Size(620, 18)
                $meta.ForeColor = $palette.Muted
                $meta.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)

                $summary = New-Object System.Windows.Forms.Label
                $summary.Text = $status.Summary
                $summary.Location = New-Object System.Drawing.Point(122, 58)
                $summary.Size = New-Object System.Drawing.Size(620, 18)
                $summary.ForeColor = $palette.Accent
                $summary.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)

                $controlId = $control.Id
                $selectControlAction = $selectControl
                $clickHandler = {
                    $null = $selectControlAction.InvokeReturnAsIs($controlId)
                }.GetNewClosure()

                foreach ($element in @($card, $badge, $title, $meta, $summary)) {
                    $element.Add_Click($clickHandler)
                }

                $card.Controls.Add($badge)
                $card.Controls.Add($title)
                $card.Controls.Add($meta)
                $card.Controls.Add($summary)
                $cardsPanel.Controls.Add($card)
                $guiState.CardMap[$control.Id] = @{
                    Panel   = $card
                    Title   = $title
                    Meta    = $meta
                    Summary = $summary
                }
            }

            $cardsPanel.ResumeLayout()

            if ($null -eq $guiState.SelectedControlId -or -not $guiState.CardMap.ContainsKey($guiState.SelectedControlId)) {
                $guiState.SelectedControlId = if (@($visibleControls).Count -gt 0) { $visibleControls[0].Id } else { $null }
            }

            & $selectControl $guiState.SelectedControlId
            $footerLabel.Text = ('Loaded {0} controls.' -f @($visibleControls).Count)
        }
        finally {
            $form.UseWaitCursor = $false
        }
    }

    $runApply = {
        if ([string]::IsNullOrWhiteSpace($guiState.SelectedControlId)) {
            return
        }

        $control = $controls | Where-Object { $_.Id -eq $guiState.SelectedControlId } | Select-Object -First 1
        $status = $guiState.StatusMap[$guiState.SelectedControlId]
        if ($null -eq $control) {
            return
        }

        if (-not (Test-ScudoAdministrator) -and $control.RequiresAdmin) {
            $elevate = [System.Windows.Forms.MessageBox]::Show(
                $form,
                'This action needs administrator rights. Relaunch the GUI elevated now?',
                'scudo',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($elevate -eq [System.Windows.Forms.DialogResult]::Yes) {
                Start-ScudoElevatedGui
                $form.Close()
            }
            return
        }

        if ($control.Id -eq 'account.create-standard-user') {
            $userName = Show-ScudoTextPrompt -Owner $form -Title 'Create standard user' -Prompt 'Enter the new local username' -Palette $palette
            if ([string]::IsNullOrWhiteSpace($userName)) {
                return
            }

            $passwordText = Show-ScudoTextPrompt -Owner $form -Title 'Create standard user' -Prompt 'Enter the password for the new account' -Palette $palette -AsPassword
            if ($null -eq $passwordText) {
                return
            }

            $securePassword = ConvertTo-SecureString -String $passwordText -AsPlainText -Force
            $result = New-ScudoStandardUser -UserName $userName -Password $securePassword
            [System.Windows.Forms.MessageBox]::Show($form, $result.Summary, 'scudo', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            & $refreshList
            return
        }

        $preflight = Get-ScudoPreflightStatus -Control $control -Action 'apply'
        if ($preflight.Blocked) {
            $message = @($preflight.Summary) + $preflight.Notes
            [System.Windows.Forms.MessageBox]::Show($form, ($message -join [Environment]::NewLine), 'scudo', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            $form,
            ("Apply '{0}' now?" -f $control.Title),
            'scudo',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        $result = Invoke-ScudoControlApply -Control $control
        Save-ScudoOperationState -Control $control -Action 'apply' -BeforeStatus $status -ResultStatus $result | Out-Null
        [System.Windows.Forms.MessageBox]::Show($form, $result.Summary, 'scudo', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        & $refreshList
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
            $elevate = [System.Windows.Forms.MessageBox]::Show(
                $form,
                'This action needs administrator rights. Relaunch the GUI elevated now?',
                'scudo',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($elevate -eq [System.Windows.Forms.DialogResult]::Yes) {
                Start-ScudoElevatedGui
                $form.Close()
            }
            return
        }

        $preflight = Get-ScudoPreflightStatus -Control $control -Action 'rollback'
        if ($preflight.Blocked) {
            $message = @($preflight.Summary) + $preflight.Notes
            [System.Windows.Forms.MessageBox]::Show($form, ($message -join [Environment]::NewLine), 'scudo', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            $form,
            ("Restore the saved state for '{0}' now?" -f $control.Title),
            'scudo',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        $currentStatus = Invoke-ScudoControlDetection -Control $control
        $result = Invoke-ScudoControlRollback -Control $control -Snapshot $snapshot
        Save-ScudoOperationState -Control $control -Action 'rollback' -BeforeStatus $currentStatus -ResultStatus $result | Out-Null
        [System.Windows.Forms.MessageBox]::Show($form, $result.Summary, 'scudo', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        & $refreshList
        & $selectControl $control.Id
    }

    $exportReports = {
        $paths = Export-ScudoReport -Results (Get-ScudoReportEntries)
        $footerLabel.Text = ('Exported report to {0}' -f $paths.MarkdownPath)
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            ("Markdown:`n{0}`n`nJSON:`n{1}" -f $paths.MarkdownPath, $paths.JsonPath),
            'scudo',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }

    $openReports = {
        $reportDirectory = Get-ScudoReportDirectory
        New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null
        Start-Process -FilePath 'explorer.exe' -ArgumentList $reportDirectory | Out-Null
    }

    $openCli = {
        $scriptPath = Join-Path -Path $script:ScudoRoot -ChildPath 'scudo.ps1'
        Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}" --cli' -f $scriptPath) | Out-Null
    }

    $refreshListAction = $refreshList
    $runApplyAction = $runApply
    $runRollbackAction = $runRollback
    $exportReportsAction = $exportReports
    $openReportsAction = $openReports
    $openCliAction = $openCli

    $categoryBox.Items.Add('All categories') | Out-Null
    foreach ($category in @($controls | Select-Object -ExpandProperty Category | Sort-Object -Unique)) {
        $categoryBox.Items.Add($category) | Out-Null
    }
    $categoryBox.SelectedIndex = 0

    $sessionLabel.Text = if (Test-ScudoAdministrator) { 'Session: elevated' } else { 'Session: not elevated' }

    $categoryBox.Add_SelectedIndexChanged({ $null = $refreshListAction.InvokeReturnAsIs() })
    $refreshButton.Add_Click({ $null = $refreshListAction.InvokeReturnAsIs() })
    $refreshSelectedButton.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace($guiState.SelectedControlId)) {
            $control = $controls | Where-Object { $_.Id -eq $guiState.SelectedControlId } | Select-Object -First 1
            if ($null -ne $control) {
                $guiState.StatusMap[$guiState.SelectedControlId] = Invoke-ScudoControlDetection -Control $control
                $null = $refreshListAction.InvokeReturnAsIs()
                $null = $selectControl.InvokeReturnAsIs($guiState.SelectedControlId)
            }
        }
    })
    $applyButton.Add_Click({ $null = $runApplyAction.InvokeReturnAsIs() })
    $rollbackButton.Add_Click({ $null = $runRollbackAction.InvokeReturnAsIs() })
    $exportButton.Add_Click({ $null = $exportReportsAction.InvokeReturnAsIs() })
    $openReportsButton.Add_Click({ $null = $openReportsAction.InvokeReturnAsIs() })
    $cliButton.Add_Click({ $null = $openCliAction.InvokeReturnAsIs() })

    & $refreshList
    [void]$form.ShowDialog()
}
