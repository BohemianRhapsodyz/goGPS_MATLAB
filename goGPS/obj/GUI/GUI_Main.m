%   CLASS GUI_Main
% =========================================================================
%
% DESCRIPTION
%   class to manages the user interface of goGPS
%
% EXAMPLE
%   ui = GUI_Main.getInstance();
%   ui.openGUI();
%
% FOR A LIST OF CONSTANTs and METHODS use doc Core_UI


%--------------------------------------------------------------------------
%               ___ ___ ___
%     __ _ ___ / __| _ | __|
%    / _` / _ \ (_ |  _|__ \
%    \__, \___/\___|_| |___/
%    |___/                    v 1.0 beta 2
%
%--------------------------------------------------------------------------
%  Copyright (C) 2009-2019 Mirko Reguzzoni, Eugenio Realini
%  Written by:       Andrea Gatti
%  Contributors:     Andrea Gatti, Giulio Tagliaferro
%  A list of all the historical goGPS contributors is in CREDITS.nfo
%--------------------------------------------------------------------------
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%--------------------------------------------------------------------------
% 01100111 01101111 01000111 01010000 01010011
%--------------------------------------------------------------------------

classdef GUI_Main < handle
    
    %% PROPERTIES SINGLETON POINTERS
    % ==================================================================================================================================================
    properties % Utility Pointers to Singletons
        log
        state
    end
    
    %% PROPERTIES GUI
    % ==================================================================================================================================================
    properties
        w_main      % Handle of the main window
        menu        % Handle of the menu
        
        info_g      % Info group
        rec_tbl     % Receiver table
        session_panel % panel of the session definition 
        session_info    % Session info
        session_summary % summary of the session
        ui_sss_start
        ui_sss_stop
        
        coo_tbl     % table of coordinates
        j_settings  % Java settings panel
        j_cmd       % Java command list panel
        ini_path    % ini path text box
        check_boxes % List of chgoGPS
        pop_ups     % List of drop down menu
        rpop_up     % Remote resources pup-up
        ropref      % Remote Orbit Preferences
        ripref      % Remote Iono preferences
        j_rrini     % ini resources file
        edit_texts  % List of editable text
        edit_texts_array % list of editable text array
        ceckboxes
        
        uip         % User Interface Pointers
    end    
    %% PROPERTIES STATUS
    % ==================================================================================================================================================
    properties (GetAccess = private, SetAccess = private)
        ok_go = false;
    end
    
    %% METHOD CREATOR
    % ==================================================================================================================================================
    methods (Static, Access = private)
        function this = GUI_Main()
            % GUI_MAIN object creator
            this.init();
            this.openGUI();
        end
    end    
    
    methods (Static, Access = public)
        function this = getInstance()
            % Get the persistent instance of the class
            persistent unique_instance_gui_main__
            
            if isempty(unique_instance_gui_main__)
                this = GUI_Main();
                unique_instance_gui_main__ = this;
                uiwait(this.w_main);                
            else
                this = unique_instance_gui_main__;
                this.init();
                this.openGUI();
                uiwait(this.w_main);                
            end
    end
end
    %% METHODS INIT
    % ==================================================================================================================================================
    methods                
        function init(this)
            this.log = Core.getLogger();
            this.state = Core.getState();
        end
        
        function openGUI(this)
            % WIN CONFIGURATION
            % L| N|    W
            %
            %
            % ----------
            % b      b b
            %
            
            if ~isempty(this.w_main) && isvalid(this.w_main)
                close(this.w_main);
            end
            % Close the old goGPS windows
            old_win = findobj('UserData', 'goGPSwin');
            close(old_win);
            
            t0 = tic();
            this.ok_go = false;
            % empty check boxes
            this.check_boxes = {};
            this.pop_ups = {};
            this.edit_texts = {};
            this.edit_texts_array = {};
            
            % Main Window ----------------------------------------------------------------------------------------------
            
            win = figure( 'Name', sprintf('%s @ %s', this.state.getPrjName, this.state.getHomeDir), ...
                'Visible', 'off', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'NumberTitle', 'off', ...
                'UserData', 'goGPSwin', ...
                'Renderer', 'opengl', ...
                'Position', [0 0 1040, 610]);
            
            this.w_main = win;            
            
            if isunix && not(ismac())
                win.Position(1) = round((win.Parent.ScreenSize(3) - win.Position(3)) / 2);
                win.Position(2) = round((win.Parent.ScreenSize(4) - win.Position(4)) / 2);
            else
                win.OuterPosition(1) = round((win.Parent.ScreenSize(3) - win.OuterPosition(3)) / 2);
                win.OuterPosition(2) = round((win.Parent.ScreenSize(4) - win.OuterPosition(4)) / 2);
            end
                        
            try
                main_bv = uix.VBox('Parent', win, ...
                    'Padding', 5, ...
                    'BackgroundColor', Core_UI.DARK_GRAY_BG);
            catch
                this.log.addError('Please install GUI Layout Toolbox (https://it.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox)');
                open('GUI Layout Toolbox 2.3.1.mltbx');
                this.log.newLine();
                this.log.addWarning('After installation re-run goGPS');
                close(win);
                return;
            end
            top_bh = uix.HBox( 'Parent', main_bv);
            
            left_bv = uix.VBox('Parent', top_bh, ...
                'Padding', 5, ...
                'BackgroundColor', Core_UI.DARK_GRAY_BG);
            
            % Set-up menu ----------------------------------------------------------------------------------------------
            
            this.addGoMenu();
            
            % Logo/title box -------------------------------------------------------------------------------------------
            
            Core_UI.insertLogoGUI(left_bv);
            
            this.insertSessionInfo(left_bv);
            
            this.insertRecList(left_bv);
            
            %this.updateRec(left_bv);
            
            % Main Panel -----------------------------------------------------------------------------------------------
            
            panel_g_border = uix.Grid('Parent', top_bh, ...
                'Padding', 5, ...
                'BackgroundColor', Core_UI.DARK_GRAY_BG);
            %panel = uix.BoxPanel('Parent', panel_border, 'Title', 'Settings' );
            
            tab_panel = uix.TabPanel('Parent', panel_g_border, ...
                'TabWidth', 100, ...
                'Padding', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'SelectionChangedFcn', @this.onTabChange);
            
            
            % Main Panel > tab1 settings
            this.j_settings = this.insertTabAdvanced(tab_panel);
            
            % Main Panel > tab2 remote resource ini
            enable_rri = true;
            if enable_rri
                this.insertTabRemoteResource(tab_panel)
            end
            
            % Main Panel > tab3 data sources
            this.j_cmd = this.insertTabCommands(tab_panel);
            
            % Main Panel > tab4 data sources
            this.insertTabDataSources(tab_panel);            
            
            % Main Panel > tab5 CRD of the stations
            this.insertTabRecSpecificParameters(tab_panel);

            % Main Panel > tab6 processing options
            this.insertTabProcessing(tab_panel);
            
            % Main Panel > tab7 atmosphere options
            this.insertTabAtmosphere(tab_panel);
            
            % Tabs settings --------------------------------------------------------------------------------------------
            
            if enable_rri
                tab_panel.TabTitles = {'Advanced', 'Resources', 'Commands', 'Data sources', 'Rec. Info', 'Processing', 'Atmosphere'};
            else
                tab_panel.TabTitles = {'Settings', 'Commands', 'Data sources', 'Rec. Info', 'Processing', 'Atmosphere'};
            end
            
            % Botton Panel ---------------------------------------------------------------------------------------------
            bottom_bh = uix.HBox( 'Parent', main_bv, ...
                'Padding', 5, ...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.DARKER_GRAY_BG);
            
            bottom_bhl = uix.HButtonBox( 'Parent', bottom_bh, ...
                'Spacing', 5, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', Core_UI.DARKER_GRAY_BG);
            
            ini_name_box = uix.HBox( 'Parent', bottom_bh, ...
                'Padding', 2, ...
                'BackgroundColor', Core_UI.DARKER_GRAY_BG);
            
            uicontrol('Parent', ini_name_box, ...
                'Style', 'Text', ...
                'String', ' Current INI path:', ...
                'ForegroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(8), ...
                'BackgroundColor', Core_UI.DARKER_GRAY_BG);   
            
            this.ini_path = uicontrol('Parent', ini_name_box, ...
                'Style', 'Text', ...
                'String', 'last_settings.ini', ...
                'ForegroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(8), ...
                'BackgroundColor', Core_UI.DARKER_GRAY_BG);            
            
            ini_name_box.Widths = [100 -1];
            
            bottom_bhr = uix.HButtonBox( 'Parent', bottom_bh, ...
                'Spacing', 5, ...
                'HorizontalAlignment', 'right', ...
                'BackgroundColor', Core_UI.DARKER_GRAY_BG);
            
            exit_but = uicontrol( 'Parent', bottom_bhl, ...
                'String', 'Exit', ...
                'Callback', @this.close); %#ok<NASGU>
            
            load_but = uicontrol( 'Parent', bottom_bhr, ...
                'String', 'Load', ...
                'Callback', @this.loadState); %#ok<NASGU>
            save_but = uicontrol( 'Parent', bottom_bhr, ...
                'String', 'Save', ...
                'Callback', @this.saveState); %#ok<NASGU>
            save_as_but = uicontrol( 'Parent', bottom_bhr, ...
                'String', 'Save As', ...
                'Callback', @this.saveAsState); %#ok<NASGU>
            go_but = uicontrol( 'Parent', bottom_bhr, ...
                'String', 'go!', ...
                'FontAngle', 'italic', ...
                'Callback', @this.go, ...
                'FontWeight', 'bold'); %#ok<NASGU>
            
            % Manage dimension -------------------------------------------------------------------------------------------
            
            main_bv.Heights = [-1 30];
            %session_height = sum(left_bv.Children(2).Children(1).Heights);
            session_height = sum(left_bv.Children(2).Heights);
            left_bv.Heights = [82 session_height -1];
            top_bh.Widths = [210 -1];
            bottom_bh.Widths = [60 -1 260];
            this.updateUI();
            
            tab_panel.Selection = 3;
            this.w_main.Visible = 'on';
            t_win = toc(t0);
            cm = this.log.getColorMode();
            this.log.setColorMode(false);
            this.log.addStatusOk(sprintf('goGPS GUI initialization completed in %.2f seconds\n', t_win));
            this.log.setColorMode(cm);
        end
    end
    %% METHODS INSERT
    % ==================================================================================================================================================
    methods
        function insertResources(this, container)
            resources_BG = Core_UI.LIGHT_GRAY_BG;
            tab = uix.Grid('Parent', container, ...
                'Padding', 5, ...
                'BackgroundColor', resources_BG);
            
            uicontrol('Parent', tab, ...
                'Style', 'Text', ...
                'String', 'Select Computational Center:', ...
                'ForegroundColor', Core_UI.BLACK, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'BackgroundColor', resources_BG);
            
            this.uip.tab_res = tab;
        end
        
        function j_cmd = insertTabCommands(this, container)
            cmd_bg = Core_UI.LIGHT_GRAY_BG;
            tab = uix.HBox('Parent', container, ...
                'Padding', 5, ...
                'BackgroundColor', cmd_bg);
             
            v_left = uix.VBox('Parent', tab, ...
                'Padding', 0, ...
                'BackgroundColor', cmd_bg);
            Core_UI.insertEmpty(tab);
            v_right = uix.VBox('Parent', tab, ...
                'Padding', 0, ...
                'BackgroundColor', cmd_bg);
            tab.Widths = [-3 5 -2];
            
            % HELP
            % --------------------------------------------------------
            help_box = uix.VBox('Parent', v_left, ...
                'Padding', 0, ...
                'BackgroundColor', cmd_bg);
            
            uicontrol('Parent', help_box, ...
                'Style', 'Text', ...
                'String', 'Command list help:', ...
                'ForegroundColor', Core_UI.BLACK, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'BackgroundColor', cmd_bg);
            
            j_help = com.mathworks.widgets.SyntaxTextPane;
            codeType = j_help.M_MIME_TYPE;  % j_settings.contentType='text/m-MATLAB'
            j_help.setContentType(codeType);
            
            j_help.setText(strrep(strCell2Str(this.state.exportCmdListHelp(), 10),'#','%'));
            j_help.setEditable(0)
            % Create the ScrollPanel containing the widget
            j_scroll_rri = com.mathworks.mwswing.MJScrollPane(j_help);
            % Inject edit box with the Java Scroll Pane into the main_window
            javacomponent(j_scroll_rri, [1 1 1 1], help_box);

            help_box.Heights = [23, -1];

            % --------------------------------------------------------

            Core_UI.insertEmpty(v_left);
            
            % COMMAND LIST
            % --------------------------------------------------------
            cmd_box = uix.VBox('Parent', v_left, ...
                'Padding', 0, ...
                'BackgroundColor', cmd_bg);
            
            uicontrol('Parent', cmd_box, ...
                'Style', 'Text', ...
                'String', 'Insert here the goGPS command list:', ...
                'ForegroundColor', Core_UI.BLACK, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'BackgroundColor', cmd_bg);

            j_cmd = com.mathworks.widgets.SyntaxTextPane;
            codeType = j_cmd.M_MIME_TYPE;  % j_settings.contentType='text/m-MATLAB'
            j_cmd.setContentType(codeType);
            str = strrep(strCell2Str(this.state.exportCmdList(), 10),'#','%');
            j_cmd.setText(str);
            % Create the ScrollPanel containing the widget
            j_scroll_settings = com.mathworks.mwswing.MJScrollPane(j_cmd);
            % Inject edit box with the Java Scroll Pane into the main_window
            [panel_j, panel_h] = javacomponent(j_scroll_settings, [1 1 1 1], cmd_box);
            
            set(j_cmd, 'FocusLostCallback', @this.refreshCmdList);
            set(j_cmd, 'FocusGainedCallback', @this.refreshCmdList);
        
            cmd_box.Heights = [23, -1];
        
            % --------------------------------------------------------

            % EXAMPLES
            % --------------------------------------------------------
            eg_box = uix.VBox('Parent', v_right);
            
            uicontrol('Parent', eg_box, ...
                'Style', 'Text', ...
                'String', 'Execution examples:', ...
                'ForegroundColor', Core_UI.BLACK, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'BackgroundColor', cmd_bg);
            
            j_eg = com.mathworks.widgets.SyntaxTextPane;
            codeType = j_eg.M_MIME_TYPE;  % j_settings.contentType='text/m-MATLAB'
            j_eg.setContentType(codeType);
            
            j_eg.setText(strrep(strCell2Str(this.state.exportCmdListExamples(), 10),'#','%'));
            j_eg.setEditable(0)
            % Create the ScrollPanel containing the widget
            j_scroll_rri = com.mathworks.mwswing.MJScrollPane(j_eg);
            % Inject edit box with the Java Scroll Pane into the main_window
            javacomponent(j_scroll_rri, [1 1 1 1], eg_box);

            eg_box.Heights = [23, -1];

            % --------------------------------------------------------
            
            v_left.Heights = [-4 5 -3];
        end
        
        function insertTabDataSources(this, container)
            data_selection_bg = Core_UI.LIGHT_GRAY_BG;
            tab = uix.VBox('Parent', container, ...
                'Padding', 5, ...
                'BackgroundColor', data_selection_bg);
            
            % --------------------------------------------------------
            
            prj_box = Core_UI.insertPanelLight(tab, 'Project');
            [~, this.edit_texts{end+1}] = Core_UI.insertDirBox(prj_box, 'Project home directory', 'prj_home', @this.onEditChange, [160 -1 25]);
            
            % --------------------------------------------------------
            
            Core_UI.insertEmpty(tab);
            
            % --------------------------------------------------------
            % Time limits
            
            this.session_panel = Core_UI.insertPanelLight(tab, 'Session');
            sss_box_v = uix.VBox('Parent', this.session_panel, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);                        
            sss_box_h = uix.HBox('Parent', sss_box_v, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);                        
            
            sss_box_l = uix.VBox('Parent', sss_box_h, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
                        
            date_g = uix.Grid( 'Parent', sss_box_l, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            uicontrol('Parent', date_g, ...
                'Style', 'Text', ...
                'String', 'Start', ...
                'FontSize', Core_UI.getFontSize(8), ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'ForegroundColor', Core_UI.BLACK);
            uicontrol('Parent', date_g, ...
                'Style', 'Text', ...
                'String', 'Stop', ...
                'FontSize', Core_UI.getFontSize(8), ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'ForegroundColor', Core_UI.BLACK);
            ts = this.state.getSessionsStart();
            te = this.state.getSessionsStop();
            if te.isempty() || ts.isempty()
                ts = GPS_Time.now();
                te = GPS_Time.now();
            end
            this.ui_sss_start = Core_UI.insertDateSpinnerHour(date_g, ts, @this.onSessionChange);
            this.ui_sss_stop = Core_UI.insertDateSpinnerHour(date_g, te, @this.onSessionChange);
            date_g.Heights = [23, 23];
            date_g.Widths = [46, 280];

            Core_UI.insertEmpty(sss_box_l);
            
            % --------------------------------------------------------

            Core_UI.insertEmpty(sss_box_h);

            % --------------------------------------------------------
            % Session size

            sss_box_r = uix.VBox('Parent', sss_box_h, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            sss_bounds = uix.VBox('Parent', sss_box_r, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            [el_group, this.edit_texts{end+1}] = Core_UI.insertEditBox(sss_bounds, 'Session duration', 'sss_duration','s', @this.onEditChange, [170 60 5 40]);
            el_group.Tag = 'sss_duration';
            [this.edit_texts_array{end+1}] = Core_UI.insertEditBoxArray(sss_bounds, 2, 'Buffers [left right]', 'sss_buffer', 's', @this.onEditArrayChange, [170 60 5 40]);
            this.edit_texts_array{end}.Tag = 'sss_buffer';
            sss_bounds.Heights = [23 23];

            Core_UI.insertEmpty(sss_box_r);
            
            
            Core_UI.insertEmpty(sss_box_v);
            
            %-------------------------------------------
            % session check boxes
            sss_check_box = uix.HBox('Parent', sss_box_v, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(sss_check_box, 'Smooth troposphere at boundaries', 'flag_smooth_tropo_out', @this.onSSSCheckBoxChange);
            this.check_boxes{end}.Tag = 'sss_smooth';
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(sss_check_box, 'Separate coordinates at boundaries', 'flag_separate_coo_at_boundary', @this.onSSSCheckBoxChange);
            this.check_boxes{end}.Tag = 'sss_bound_coo';
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(sss_check_box, 'RINEX based session', 'sss_file_based', @this.onSSSCheckBoxChange);

            Core_UI.insertEmpty(sss_box_v);
            
            % --------------------------------------------------------
            % Session char
            sss_list_box_g = uix.HBox('Parent', sss_box_v, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(sss_list_box_g, 'Session character list - key: $(S)', 'sss_id_list', '', @this.onEditChange, [200 -1 0 0]);
            %this.edit_texts{end}.HorizontalAlignment = 'left';
            this.edit_texts{end}.FontName = 'Courier New';
            this.edit_texts{end}.FontSize = Core_UI.getFontSize(9);
            this.edit_texts{end}.FontWeight = 'bold';
            
            Core_UI.insertEmpty(sss_list_box_g);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(sss_list_box_g, 'First', 'sss_id_start', '', @this.onEditChange, [30 20 0 0]);
            this.edit_texts{end}.FontName = 'Courier New';
            this.edit_texts{end}.FontSize = Core_UI.getFontSize(9);
            this.edit_texts{end}.FontWeight = 'bold';
            Core_UI.insertEmpty(sss_list_box_g);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(sss_list_box_g, 'Last', 'sss_id_stop', '', @this.onEditChange, [30 20 0 0]);
            this.edit_texts{end}.FontName = 'Courier New';
            this.edit_texts{end}.FontSize = Core_UI.getFontSize(9);
            this.edit_texts{end}.FontWeight = 'bold';
            sss_list_box_g.Widths = [-1 5 50 5 50];

            sss_box_h.Widths      = [340 10 -1];
            sss_box_l.Heights     = [46 5];
            sss_check_box.Widths  = [300 300 -1];
            sss_box_r.Heights     = [46 5];
            sss_box_v.Heights     = [51 5 23 5 23];
            
            % --------------------------------------------------------
            
            Core_UI.insertEmpty(tab);
            
            % --------------------------------------------------------
            
            this.insertStations(tab);
            
            % --------------------------------------------------------
            
            tab.Heights = [55 5 135 5 -1];
        end
        
        function insertStations(this, container)
            box = Core_UI.insertPanelLight(container, 'Stations');
            
            box_g = uix.VBox('Parent', box, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            [~, this.edit_texts{end+1}, this.edit_texts{end+2}] = Core_UI.insertDirFileBoxObsML(box_g, 'Observation', 'obs_dir', 'obs_name', @this.onEditChange, {[170 -1 25], [170 -1 25]});
            Core_UI.insertEmpty(box_g);
            [~, this.edit_texts{end+1}, this.edit_texts{end+2}] = Core_UI.insertDirFileBox(box_g, 'Antex (ATX) filename', 'atx_dir', 'atx_name', @this.onEditChange, [170 -3 5 -1 25]);
            Core_UI.insertEmpty(box_g);
            
            box_gh = uix.HBox('Parent', box_g, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            [~, this.edit_texts{end+1}, this.edit_texts{end+2}] = Core_UI.insertDirFileBox(box_gh, 'Ocean loading filename', 'ocean_dir', 'ocean_name', @this.onEditChange, [170 -3 5 -1 25]);
            plot_rec = uicontrol( 'Parent', box_gh, ...
                'String', 'Get missing BLQ', ...
                'Callback', @this.openGetChalmerString);
            box_gh.Widths = [-1 120];
            box_g.Heights = [-1 5 23 5 23];
        end
        
        function openGetChalmerString(this, caller, event)
            % Update file name list and plot daily availability of the files
            %
            % SYNTAX:
            %   this.updateAndPlotRecList            
            GUI_Chalmers;            
        end
        
        function insertTabProcessing(this, container)
            data_selection_bg = Core_UI.LIGHT_GRAY_BG;
            tab = uix.Grid('Parent', container, ...
                'Padding', 5, ...
                'BackgroundColor', data_selection_bg);
            
            % --------------------------------------------------------
            
            ds_box = Core_UI.insertPanelLight(tab, 'Data Selection');
            
            % --------------------------------------------------------
            ds_box_g = uix.VBox('Parent', ds_box, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            uicontrol('Parent', ds_box_g, ...
                'Style', 'Text', ...
                'String', 'Data to keep during processing (if present in the receiver data)', ...
                'ForegroundColor', Core_UI.BLACK, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'BackgroundColor', data_selection_bg);
            
            Core_UI.insertHBarLight(ds_box_g);
            
            ds_h_box = uix.HBox('Parent', ds_box_g, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            err_box_g = uix.VBox('Parent', ds_h_box, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(err_box_g, 'Min satellites per epoch', 'min_n_sat', 'n', @this.onEditChange, [175 40 5 50]);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(err_box_g, 'Data cut-off angle', 'cut_off', 'deg', @this.onEditChange, [175 40 5 50]);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(err_box_g, 'SNR threshold', 'snr_thr', 'dBHz', @this.onEditChange, [175 40 5 50]);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(err_box_g, 'Min arc length', 'min_arc', 'epochs', @this.onEditChange, [175 40 5 50]);
            Core_UI.insertEmpty(err_box_g);

            %[~, this.edit_texts{end+1}] = Core_UI.insertEditBox(err_box_g, 'Sat to remove', 'sat_to_remove', '', @this.onEditChange, [95 120 0 40 ]);
            %Core_UI.insertEmpty(err_box_g);
            
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(err_box_g, 'Max code positioning err', 'pp_spp_thr', 'm', @this.onEditChange, [175 40 5 50]);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(err_box_g, 'Max code observation err', 'pp_max_code_err_thr', 'm', @this.onEditChange, [175 40 5 50]);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(err_box_g, 'Max phase observation err', 'pp_max_phase_err_thr', 'm', @this.onEditChange, [175 40 5 50]);
            Core_UI.insertEmpty(err_box_g);
            err_box_g.Heights = [(23 * ones(1,4)) 10 (23 * ones(1,3)) -1];
            
            Core_UI.insertEmpty(ds_h_box);
            
            ss_panel  = this.insertSatSelector(ds_h_box); %#ok<NASGU>
            
            ds_h_box.Widths = [280 3 -1];
            
            %Core_UI.insertEmpty(ds_box_g);
            
            % --------------------------------------------------------
            
            Core_UI.insertEmpty(tab);
            
            % --------------------------------------------------------
            %  ----h-----------------
            %  -ppp--E--r--E--out--
            
            opt_h = uix.HBox('Parent', tab, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            opt_l = uix.VBox('Parent', opt_h, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            opt_tlh = uix.HBox('Parent', opt_l, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            opt_tll = uix.VBox('Parent', opt_tlh, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            Core_UI.insertEmpty(opt_tlh);
            
            opt_tlr = uix.VBox('Parent', opt_tlh, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
                         
            % left top left
            ppp_panel = this.insertCorrections(opt_tll); %#ok<NASGU>
                        
            % left top left right
            pp_panel = this.insertTabProcessingOptions(opt_tlr);
            Core_UI.insertEmpty(opt_tlr);            
            coo_panel = this.insertCooOptions(opt_tlr);

            % left bottom
            Core_UI.insertEmpty(opt_l);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(opt_l, 'Out directory', 'out_dir', @this.onEditChange, [100 -1 25]);
            Core_UI.insertEmpty(opt_l);

            Core_UI.insertEmpty(opt_h);
            
            % right                                                           
            opt_out = this.insertOutOptions(opt_h); %#ok<NASGU>
            
            opt_l.Heights = [240 1 23 -1];
            opt_tll.Heights = 233;
            opt_tlr.Heights = [138, 5, 93];
            
            opt_tlh.Widths = [195 5 -1];
            opt_h.Widths = [-1 5 190];
            
            % --------------------------------------------------------
            
            ds_box_g.Heights = [18 15 -1];
            
            tab.Heights = [230 5 -1];
            
            this.uip.tab_proc = tab;
        end
        
        function ocean_panel = insertOceanOptions(this, container)
            ocean_panel = Core_UI.insertPanelLight(container, 'Ocean loading file');
            opt_grid = uix.Grid('Parent', ocean_panel,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            [~, this.edit_texts{end+1}, this.edit_texts{end+2}] = Core_UI.insertDirFileBox(ocean_panel, '', 'ocean_dir', 'ocean_name', @this.onEditChange, [0 -3 5 -1 25]);
        end
        
        function ocean_panel = insertCooOptions(this, container)
            ocean_panel = Core_UI.insertPanelLight(container, 'Coordinates estimation');
            opt_v = uix.VBox('Parent', ocean_panel,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Separate antenna center for each GNSS','flag_separate_apc', @this.onCheckBoxChange);
            %this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Dynamic solution','rec_dyn_mode', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Additional coordinates rate','flag_coo_rate', @this.onCheckBoxChange);
            [this.edit_texts_array{end+1}] = Core_UI.insertEditBoxArray(opt_v, 3, '', 'coo_rates', 's', @this.onEditArrayChange, [0 60 5 40]);
            set( opt_v, 'Heights', [22 22 22] );
        end
        
        function proc_opt = insertTabProcessingOptions(this, container)
            proc_opt = Core_UI.insertPanelLight(container, 'Options');
            opt_grid = uix.VBox('Parent', proc_opt,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(opt_grid, 'Observation weighting', this.state.W_SMODE, 'w_mode', @this.onPopUpChange);
            Core_UI.insertEmpty(opt_grid);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(opt_grid, 'PPP Snooping / Reweight', this.state.PPP_REWEIGHT_LABEL, 'ppp_reweight_mode', @this.onPopUpChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'PPP Try to fix Ambiguity (Experimental)', 'flag_ppp_amb_fix', @this.onCheckBoxChange);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(opt_grid, 'NET Snooping / Reweight', this.state.NET_REWEIGHT_LABEL, 'net_reweight_mode', @this.onPopUpChange);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(opt_grid, 'NET fixing approach', this.state.NET_AMB_FIX_LABEL, 'net_amb_fix_approach', @this.onPopUpChange);
            opt_grid.Heights = [22 5 22 22 22 22];
        end
        
        function crd_panel = insertCrdFile(this, container)
            crd_panel = Core_UI.insertPanelLight(container, 'Stations a-priori coordinates');
            opt_grid = uix.Grid('Parent', crd_panel,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            [~, this.edit_texts{end+1}, this.edit_texts{end+1}] = Core_UI.insertDirFileBox(opt_grid, 'CRD filename', 'crd_dir', 'crd_name', @this.onEditChange);
        end
        
        function ss_panel = insertSatSelector(this, container)
            % Constellation selection
            ss_panel = Core_UI.insertPanelLight(container, 'Constellation Selection');
            ss_panel.FontWeight = 'normal';
            
            h_box_cc = uix.HBox('Parent', ss_panel, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            v_but_bx_cc = uix.VButtonBox('Parent', h_box_cc, ...
                'ButtonSize', [100 20], ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(v_but_bx_cc, 'GPS',     'G_is_active', @this.onCheckBoxConstChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(v_but_bx_cc, 'GLONASS', 'R_is_active', @this.onCheckBoxConstChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(v_but_bx_cc, 'Galileo', 'E_is_active', @this.onCheckBoxConstChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(v_but_bx_cc, 'QZSS',    'J_is_active', @this.onCheckBoxConstChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(v_but_bx_cc, 'Beidou',  'C_is_active', @this.onCheckBoxConstChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(v_but_bx_cc, 'IRNSS',   'I_is_active', @this.onCheckBoxConstChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(v_but_bx_cc, 'SBAS',    'S_is_active', @this.onCheckBoxConstChange);
            this.check_boxes{end}.Enable = 'off';
            
            Core_UI.insertVBarLight(h_box_cc);
            
            %%% frequency selection
            v_bx_freq = uix.VBox('Parent', h_box_cc, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            n_b_gps = uix.HButtonBox('Parent', v_bx_freq, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_gps, '(L1) L1', 'GPS_L1', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_gps, '(L2) L2', 'GPS_L2', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_gps, '(L5) L5', 'GPS_L5', @this.onCheckBoxCCChange);
            
            n_b_glo = uix.HButtonBox('Parent', v_bx_freq, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_glo, '(L1) G1', 'GLO_G1', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_glo, '(L2) G2', 'GLO_G2', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_glo, '(L3) G3', 'GLO_G3', @this.onCheckBoxCCChange);
            
            n_b_gal = uix.HButtonBox('Parent', v_bx_freq, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_gal, '(L1) E1 ', 'GAL_E1', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_gal, '(L5) E5a', 'GAL_E5a', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_gal, '(L7) E5b', 'GAL_E5b', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_gal, '(L8) E5 ', 'GAL_E5', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_gal, '(L6) E6 ', 'GAL_E6', @this.onCheckBoxCCChange);
            
            n_b_qzs = uix.HButtonBox('Parent', v_bx_freq, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_qzs, '(L1) L1', 'QZS_L1', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_qzs, '(L2) L2', 'QZS_L2', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_qzs, '(L5) L5', 'QZS_L5', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_qzs, '(L6) L6', 'QZS_LEX6', @this.onCheckBoxCCChange);
            
            n_b_bei = uix.HButtonBox('Parent', v_bx_freq, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_bei, '(L2) B1', 'BDS_B1', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_bei, '(L7) B2', 'BDS_B2', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_bei, '(L6) B3', 'BDS_B3', @this.onCheckBoxCCChange);
            
            n_b_irn = uix.HButtonBox('Parent', v_bx_freq, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_irn, '(L5) L5', 'IRN_L5', @this.onCheckBoxCCChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_irn, '(L9) S ', 'IRN_S', @this.onCheckBoxCCChange);
            
            n_b_sbs = uix.HButtonBox('Parent', v_bx_freq, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_sbs, '(L1) L1', 'SBS_L1', @this.onCheckBoxCCChange);
            this.check_boxes{end}.Enable = 'off';
            this.check_boxes{end+1} = Core_UI.insertCheckBoxCC(n_b_sbs, '(L5) L5', 'SBS_L5', @this.onCheckBoxCCChange);
            this.check_boxes{end}.Enable = 'off';
            
            n_b_gps.ButtonSize(1) = 72;
            n_b_glo.ButtonSize(1) = 72;
            n_b_gal.ButtonSize(1) = 72;
            n_b_qzs.ButtonSize(1) = 72;
            n_b_bei.ButtonSize(1) = 72;
            n_b_irn.ButtonSize(1) = 72;
            n_b_sbs.ButtonSize(1) = 72;
            
            h_box_cc.Widths = [80 20 -1];
        end
        
        function out_panel = insertOutOptions(this, container)
            %%% processing options
            opt_container = uix.VBox('Parent', container,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            out_panel = Core_UI.insertPanelLight(opt_container, 'Results to store in out');
            opt_v = uix.VBox('Parent', out_panel,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Dt (clock errors)',       'flag_out_dt', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'PWV',                     'flag_out_pwv', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'ZWD',                     'flag_out_zwd', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'ZTD',                     'flag_out_ztd', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Tropo Gradients',         'flag_out_tropo_g', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'A-priori tropo',          'flag_out_apr_tropo', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'P / T / H',               'flag_out_pth', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Outliers / CS',           'flag_out_ocs', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Quality (SNR)',           'flag_out_quality', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Azimuth / Elevation',     'flag_out_azel', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Residuals',               'flag_out_res', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_v, 'Mapping functions',       'flag_out_mf', @this.onCheckBoxChange);           
            %Core_UI.insertEmpty(opt_container);
            %opt_container.Heights = [260 -1];
        end
        
        function ppp_panel = insertCorrections(this, container)
            %%% processing options
            ppp_panel = Core_UI.insertPanelLight(container, 'Observations "corrections"');
            opt_grid = uix.Grid('Parent', ppp_panel,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'Receiver PCO/PCV',        'flag_rec_pcv', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'Solid Earth Tide',        'flag_solid_earth', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'Pole Earth Tide',         'flag_pole_tide', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'Phase Wind Up',           'flag_phase_wind', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'Shapiro Delay',           'flag_shapiro', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'Ocean Loading',           'flag_ocean_load', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'Atmospheric Loading',     'flag_atm_load', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'High Order Ionosphere',   'flag_hoi', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(opt_grid, 'Use a-priori Iono Model', 'flag_apr_iono', @this.onCheckBoxChange);
            
            opt_grid.Widths = -1;
        end
        
        function insertTabRecSpecificParameters(this, container)
            tab = uix.Grid('Parent', container, ...
                'Padding', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);            
            
            %%% Rec
            box = Core_UI.insertPanelLight(tab, 'Station Coordinates');
            vbox = uix.VBox('Parent', box,...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);            
            [~, this.edit_texts{end+1}, this.edit_texts{end+2}] = Core_UI.insertDirFileBox(vbox, 'CRD filename', 'crd_dir', 'crd_name', @this.onEditChange, [170 -3 5 -1 25]);
            Core_UI.insertEmpty(vbox);
            table_hbox = uix.HBox('Parent', vbox,...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            vbox.Heights = [23 5 -1];
                        
            % Create UITable
            this.coo_tbl = uitable('Parent', table_hbox, ...
                'CellEditCallback', @this.dataCrdChange);
            but_box = uix.VBox('Parent', table_hbox,...
                'Spacing', 0, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            table_hbox.Widths = [-1 120];
                        
            del_row_but = uicontrol( 'Parent', but_box, ...
                'String', 'Clear all', ...
                'TooltipString', 'Remove all the entries', ...
                'Callback', @this.delCrd); %#ok<NASGU>

            add_row_but = uicontrol( 'Parent', but_box, ...
                'String', 'Add a line', ...
                'TooltipString', 'Add a new entry to CRD file', ...
                'Callback', @this.addCrdRow); %#ok<NASGU>
            
            del_row_but = uicontrol( 'Parent', but_box, ...
                'String', 'Remove selected', ...
                'TooltipString', 'Remove row/s with selected cells', ...
                'Callback', @this.delCrdRow); %#ok<NASGU>

            importFromRin = uicontrol( 'Parent', but_box, ...
                'String', 'Import from RINEX', ...
                'TooltipString', 'Import from RINEX', ...
                'Callback', @this.rin2Crd); %#ok<NASGU>
            
            Core_UI.insertEmpty(but_box);

            save = uicontrol( 'Parent', but_box, ...
                'String', 'Save', ...
                'TooltipString', 'Save file in the current location', ...
                'Callback', @this.saveCrd); %#ok<NASGU>
            
            save_as = uicontrol( 'Parent', but_box, ...
                'String', 'Save as', ...
                'TooltipString', 'Save file as', ...
                'Callback', @this.saveAsCrd); %#ok<NASGU>

            save_as_default = uicontrol( 'Parent', but_box, ...
                'String', 'Save (Default)', ...
                'TooltipString', 'Save file in the default position (PRJ_HOME/station/crd/station.crd)', ...
                'Callback', @this.saveAsDefaultCrd); %#ok<NASGU>

            Core_UI.insertEmpty(but_box);
            
            add_row_but = uicontrol( 'Parent', but_box, ...
                'String', 'ShowMap', ...
                'TooltipString', 'Show stations on a map', ...
                'Callback', @this.showCrdMap); %#ok<NASGU>

            but_box.Heights = [25 25 25 25 -1 25 25 25 15 25];
            this.coo_tbl.Position = [25 40 250 100];
            
            this.coo_tbl.ColumnName = {'Marker Name'; 'X [m]'; 'Y [m]'; 'Z [m]'; 'type'; 'start'; 'stop'; 'dX/dt [m/y]'; 'dY/dt [m/y]'; 'dZ/dt [m/y]'};
            colTypes = {'char', 'long g', 'long g', 'long g', Core_Reference_Frame.FLAG_STRING, 'char', 'char', 'short g', 'short g', 'short g'};
            this.coo_tbl.ColumnFormat = colTypes;
            this.coo_tbl.ColumnEditable = [true true true true true true true true true true];
            this.coo_tbl.ColumnWidth = {'auto', 100, 100, 100, 130, 120, 120, 'auto', 'auto', 'auto'};            
            this.updateCooTable();
            this.coo_tbl.addlistener('Data','PostSet', @(src,event)this.dataCrdChange(this.coo_tbl,src,event));
        end
        
        function rf = crd2RefFrame(this)
            % Import in the reference frame object the coordinates from the GUI table
            %
            % SYNTAX:
            %   rf = this.crd2RefFrame()
            rf = Core.getReferenceFrame();
            rf.importTableData(this.coo_tbl.Data);
            this.updateCooTable();
        end
        
        function saveCrd(this, tbl, src, event)
            % Save CRD
            rf = this.crd2RefFrame();
            rf.export(this.state.getCrdFile);
        end
        
        function saveAsCrd(this, tbl, src, event)
            % Save CRD as ...
            
            crd_dir = this.state.getCrdDir();
            
            [file_name, path_name] = uiputfile('*.crd','Save your crd', crd_dir);
            
            if path_name == 0 %if the user pressed cancelled, then we exit this callback
                return
            end
            
            % build the path name of the save location
            crd_path = fullfile(path_name,file_name);
            try
                rf = this.crd2RefFrame();
                this.state.setCrdFile(crd_path);
                obj = findobj('UserData', 'crd_name'); obj.String = file_name;
                obj = findobj('UserData', 'crd_dir'); obj.String = path_name;
                rf.export(crd_path);
                this.log.addMarkedMessage(sprintf('The file has been saved correctly on:\n     %s', crd_path));
            catch ex
                this.log.addError(sprintf('Export failed!\n%s', ex.message));
            end
        end
        
        function saveAsDefaultCrd(this, tbl, src, event)
            % Save CRD in the default location
                        
            path_name = fullfile(this.state.getHomeDir, 'station', 'CRD');
            file_name = 'stations.crd';
            % build the path name of the save location
            crd_path = fullfile(path_name, file_name);
            try
                rf = this.crd2RefFrame();
                this.state.setCrdFile(crd_path);
                obj = findobj('UserData', 'crd_name'); obj.String = file_name;
                obj = findobj('UserData', 'crd_dir'); obj.String = path_name;
                rf.export(crd_path);
                this.log.addMarkedMessage(sprintf('The file has been saved correctly on:\n     %s', crd_path));
            catch ex
                this.log.addError(sprintf('Export failed!\n%s', ex.message));
            end
        end
        
        function dataCrdChange(this, tbl, src, event)
            % Add a new row to the CRD table
            for i = 1 : size(tbl.Data, 1)
                if ischar(this.coo_tbl.Data{i,1})
                    name_start = find(this.coo_tbl.Data{i,1} == '>', 1, 'last');
                    name_start = iif(isempty(name_start), 1, name_start + 1);
                    name = this.coo_tbl.Data{i,1}(name_start : end);
                else
                    name = 'NAME';
                end
                this.coo_tbl.Data{i,1} = ['<html><tr><td width=9999 align=center style="color: #6666FF; font-weight: bold">' name];
            end
        end

        function rin2Crd(this, caller, event)
            % Add a new row to the CRD table            
            rec_path = Core.getState.getRecPath();
            data = this.coo_tbl.Data;            
            for r = 1 : numel(rec_path)
                fr = File_Rinex(rec_path{r}, 100);
                if fr.isValid()
                    name = fr.marker_name{1};
                    name = name(1:min(4, numel(name)));
                    xyz = median(fr.coo.getXYZ,1,'omitnan');
                    time_start = fr.first_epoch.first.toString('yyyy-mm-dd HH:MM:SS');
                    time_stop = fr.last_epoch.last.toString('yyyy-mm-dd HH:MM:SS');
        
                    if ~isempty(xyz)
                        if ~isempty(data)
                            data = [data; {name, xyz(1), xyz(2), xyz(3), Core_Reference_Frame.FLAG_STRING{2}, time_start, time_stop, 0, 0, 0}];
                        else
                            data = {name, xyz(1), xyz(2), xyz(3), Core_Reference_Frame.FLAG_STRING{2}, time_start, time_stop, 0, 0, 0};
                        end
                    end
                end
            end
            this.coo_tbl.Data = data;            
        end
        
        function showCrdMap(this, caller, event)
            f = figure;
            maximizeFig(f);            
            data = this.coo_tbl.Data;
            
            % get marker names:
            name = {};
            for i = 1 : size(data, 1)
                if ischar(data{i,1})
                    name_start = find(data{i,1} == '>', 1, 'last');
                    name_start = iif(isempty(name_start), 1, name_start + 1);
                    name{i} = data{i,1}(name_start : end);
                else
                    name{i} = 'NAME';
                end                
            end

            % get Location
            [lat, lon] = cart2geod([[data{:,2}]' [data{:,3}]' [data{:,4}]']);
            
            plot(lon(:)./pi*180, lat(:)./pi*180,'.k', 'MarkerSize', 5); hold on;            
            % Label BG (in background w.r.t. the point)
            for r = 1 : size(data, 1)
                text(lon(r)./pi*180, lat(r)./pi*180, '              ', ...
                    'FontWeight', 'bold', 'FontSize', 10, 'Color', [0 0 0], ...
                    'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                    'Margin', 2, 'LineWidth', 2, ...
                    'HorizontalAlignment','left');
            end
            
            % Plot
            for r = 1 : size(data, 1)
                plot(lon(r)./pi*180, lat(r)./pi*180, '.', 'MarkerSize', 45, 'Color', Core_UI.getColor(r, size(data, 1)));
            end
            plot(lon(:)./pi*180, lat(:)./pi*180,'.k','MarkerSize', 5);
            plot(lon(:)./pi*180, lat(:)./pi*180,'ko','MarkerSize', 15, 'LineWidth', 2);
            
            if size(data, 1) == 1
                lon_lim = minMax(lon/pi*180);
                lat_lim = minMax(lat/pi*180);
                lon_lim(1) = lon_lim(1) - 0.1;
                lon_lim(2) = lon_lim(2) + 0.1;
                lat_lim(1) = lat_lim(1) - 0.1;
                lat_lim(2) = lat_lim(2) + 0.1;
            else
                lon_lim = xlim();
                lon_lim(1) = lon_lim(1) - diff(lon_lim)/3;
                lon_lim(2) = lon_lim(2) + diff(lon_lim)/3;
                lat_lim = ylim();
                lat_lim(1) = lat_lim(1) - diff(lat_lim)/3;
                lat_lim(2) = lat_lim(2) + diff(lat_lim)/3;
            end
            
            xlim(lon_lim);
            ylim(lat_lim);
            
            for r = 1 : size(data, 1)
                text(lon(r)./pi*180, lat(r)./pi*180, ['    ' name{r}], ...
                    'FontWeight', 'bold', 'FontSize', 10, 'Color', [0 0 0], ...
                    'Margin', 2, 'LineWidth', 2, ...
                    'HorizontalAlignment','left');
            end
            
            plot_google_map('alpha', 0.95, 'MapType', 'satellite');
            title('Receiver position');
            xlabel('Longitude [deg]');
            ylabel('Latitude [deg]');
        end
        
        function addCrdRow(this, caller, event)
            % Add a new row to the CRD table
            this.coo_tbl.Data = [this.coo_tbl.Data; {'NAME', 0, 0, 0, Core_Reference_Frame.FLAG_STRING{1}, GPS_Time(0).toString('yyyy-mm-dd HH:MM:SS'), GPS_Time(datenum('2099/12/31')).toString('yyyy-mm-dd HH:MM:SS'), 0, 0, 0}];
        end
        
        function delCrd(this, caller, event)
            % Clear the CRD table            
            this.coo_tbl.Data(:, :) = [];
        end
        
        function delCrdRow(this, caller, event)
            % Del a selected row from the CRD table            
            j_scroll_table = findjobj(this.coo_tbl);
            j_ui_table =  j_scroll_table.getViewport.getView;
            this.coo_tbl.Data(j_ui_table.getSelectedRows + 1, :) = [];
        end 
        
        function updateCooTable(this)
            % Update the table of coordinates (CRD file interface)
            rf = Core.getReferenceFrame();
            if ~rf.isValid && (exist(Core.getState.getCrdFile, 'file') == 2)
                rf.init();
            end
            this.coo_tbl.Data = rf.getEntryCell();
            this.coo_tbl.RowName = {};
        end
        
        function insertTabAtmosphere(this, container)
            tab = uix.Grid('Parent', container, ...
                'Padding', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            %%% IONO
            iono_options = Core_UI.insertPanelLight(tab, 'Ionosphere options');
            iono_opt_grid = uix.VBox('Parent', iono_options,...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(iono_opt_grid, 'Ionosphere Management', this.state.IE_LABEL, 'iono_management', @this.onPopUpChange);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(iono_opt_grid, 'Ionosphere a-priori Model',this.state.IONO_LABEL ,'iono_model', @this.onPopUpChange);
            
            Core_UI.insertEmpty(tab);
            
            %%% TROPO
            tropo_options = Core_UI.insertPanelLight(tab, 'Tropospheric options');
            tropo_opt_grid = uix.VBox('Parent', tropo_options,...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            tropo_opt_est_grid = uix.HBox('Parent', tropo_opt_grid,...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(tropo_opt_est_grid, 'Estimate ZTD', 'flag_tropo', @this.onCheckBoxChange);
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(tropo_opt_est_grid, 'Estimates ZTD gradients', 'flag_tropo_gradient', @this.onCheckBoxChange);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(tropo_opt_grid, 'Absolute tropo in network', 'flag_free_net_tropo', @this.onCheckBoxChange);

            
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(tropo_opt_grid, 'Mapping function', this.state.MF_LABEL, 'mapping_function', @this.onPopUpChange);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(tropo_opt_grid, 'A-priori zenith delay',this.state.ZD_LABEL ,'zd_model', @this.onPopUpChange);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(tropo_opt_grid, 'Meteo Data',this.state.MD_LABEL ,'meteo_data',@this.onPopUpChange);
            [~, this.edit_texts{end+1}, this.edit_texts{end+2}] = Core_UI.insertDirFileBoxMetML(tropo_opt_grid, 'MET', 'met_dir', 'met_name', @this.onEditChange,  {[100 -1 25], [100 -1 25]});
            tropo_opt_grid.Heights = [20 * ones(5,1); -1];
            tropo_opt_est_grid.Widths = [150; -1];

            Core_UI.insertEmpty(tab);
            
            %%% TROPO ADV
            tropo_opt_adv = Core_UI.insertPanelLight(tab, 'Advanced regularization options');
            tropo_opt_v_adv = uix.VBox('Parent', tropo_opt_adv,...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            clock_reg_hbox = uix.HBox('Parent', tropo_opt_v_adv,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(clock_reg_hbox, 'clock regularization', 'std_clock', 'm/sqrt(h)', @this.onEditChange, [-1 80 5 70]);
            Core_UI.insertEmpty(clock_reg_hbox);
            clock_reg_hbox.Widths = [332 -1];
            tropo_opt_hbox_adv = uix.HBox('Parent', tropo_opt_v_adv,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            tropo_opt_v_adv.Heights = [25 -1];
            
            tropo_opt_vl_adv = uix.VBox('Parent', tropo_opt_hbox_adv,...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            Core_UI.insertEmpty(tropo_opt_hbox_adv);
            tropo_opt_vr_adv = uix.VBox('Parent', tropo_opt_hbox_adv,...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            tropo_opt_hbox_adv.Widths = [-1 20 -1];
            
            uicontrol('Parent', tropo_opt_vl_adv, ...
                'Style', 'Text', ...
                'String', 'ZTD estimation', ...
                'ForegroundColor', Core_UI.BLACK, ...
                'FontWeight' , 'bold', ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(8), ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            uicontrol('Parent', tropo_opt_vr_adv, ...
                'Style', 'Text', ...
                'String', 'ZTD gradients estimation', ...
                'ForegroundColor', Core_UI.BLACK, ...
                'FontWeight' , 'bold', ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(8), ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(tropo_opt_vl_adv, 'Regularization', 'std_tropo', 'm/sqrt(h)', @this.onEditChange, [-1 80 5 70]);            
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(tropo_opt_vl_adv, 'Spline rate', 'spline_rate_tropo', 's', @this.onEditChange, [-1 80 5 70]);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(tropo_opt_vl_adv, 'Order of the spline',this.state.SPLINE_TROPO_ORDER_LABEL ,'spline_tropo_order', @this.onPopUpChange, [-1 160]);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(tropo_opt_vr_adv, 'Regularization', 'std_tropo_gradient', 'm/sqrt(h)', @this.onEditChange, [-1 80 5 70]);
            [~, this.edit_texts{end+1}] = Core_UI.insertEditBox(tropo_opt_vr_adv, 'Spline rate', 'spline_rate_tropo_gradient', 's', @this.onEditChange, [-1 80 5 70]);
            [~, this.pop_ups{end+1}] = Core_UI.insertPopUpLight(tropo_opt_vr_adv, 'Order of the spline',this.state.SPLINE_TROPO_GRADIENT_ORDER_LABEL ,'spline_tropo_gradient_order', @this.onPopUpChange, [-1 160]);
                        
            tab.Heights = [80 5 250 5 -1];
            tab.Widths = 700;
            
            this.uip.tab_atmo = tab;
        end
        
        function insertTabRemoteResource(this, container)
            tab = uix.Grid('Parent', container);
            
            tab_bv = uix.VBox( 'Parent', tab, ...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
%             uicontrol('Parent', tab_bv, ...
%                 'Style', 'Text', ...
%                 'HorizontalAlignment', 'left', ...
%                 'String', 'Remote Resources ini file contains download locations - not editable from GUI', ...
%                 'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
%                 'ForegroundColor', Core_UI.BLACK, ...
%                 'FontSize', Core_UI.getFontSize(10), ...
%                 'FontWeight', 'bold');
            
            uicontrol('Parent', tab_bv, ...
                'Style', 'Text', ...
                'HorizontalAlignment', 'left', ...
                'String', ['File path: ' this.state.getRemoteSourceFile], ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'ForegroundColor', 0.3 * ones(3, 1), ...
                'FontSize', Core_UI.getFontSize(7.5));
            
            Core_UI.insertHBarLight(tab_bv);
            
            this.check_boxes{end+1} = Core_UI.insertCheckBoxLight(tab_bv, 'Allow automatic download of missing resources', 'flag_download', @this.onCheckBoxChange);

            try
                r_man = Remote_Resource_Manager.getInstance(this.state.getRemoteSourceFile());
                [tmp, this.rpop_up] = Core_UI.insertPopUpLight(tab_bv, 'Center', r_man.getCenterListExtended, 'selected_center', @this.onResourcesPopUpChange);                
            catch
                str = sprintf('[!!] Resource file missing:\n"%s"\nnot found\n\ngoGPS may not work properly', this.state.getRemoteSourceFile);
            end
            
            box_opref = uix.HBox( 'Parent', tab_bv, ...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            uicontrol('Parent', box_opref, ...
                'Style', 'Text', ...
                'HorizontalAlignment', 'left', ...
                'String', 'Center orbit type preference', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'ForegroundColor', Core_UI.BLACK, ...
                'FontSize', Core_UI.getFontSize(9));
          
            this.ropref = {};
            this.ropref{1} = Core_UI.insertCheckBoxLight(box_opref, 'Final', 'orbit1', @this.onResourcesPrefChange);
            this.ropref{2} = Core_UI.insertCheckBoxLight(box_opref, 'Rapid', 'orbit2', @this.onResourcesPrefChange);
            this.ropref{3} = Core_UI.insertCheckBoxLight(box_opref, 'Ultra rapid', 'orbit3', @this.onResourcesPrefChange);
            this.ropref{4} = Core_UI.insertCheckBoxLight(box_opref, 'Broadcast', 'orbit4', @this.onResourcesPrefChange);
            box_opref.Widths = [250 -1 -1 -1 -1];
            
            box_ipref = uix.HBox( 'Parent', tab_bv, ...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            uicontrol('Parent', box_ipref, ...
                'Style', 'Text', ...
                'HorizontalAlignment', 'left', ...
                'String', 'Center iono type preference', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'ForegroundColor', Core_UI.BLACK, ...
                'FontSize', Core_UI.getFontSize(9));
            
            this.ripref = {};
            this.ripref{1} = Core_UI.insertCheckBoxLight(box_ipref, 'Final', 'iono1', @this.onResourcesPrefChange);
            this.ripref{2} = Core_UI.insertCheckBoxLight(box_ipref, 'Predicted 1 day', 'iono2', @this.onResourcesPrefChange);
            this.ripref{3} = Core_UI.insertCheckBoxLight(box_ipref, 'Predicted 2 days', 'iono3', @this.onResourcesPrefChange);
            this.ripref{4} = Core_UI.insertCheckBoxLight(box_ipref, 'Broadcast', 'iono4', @this.onResourcesPrefChange);
            box_ipref.Widths = [250 -1 -1 -1 -1];
            
            % Resource tree
            Core_UI.insertEmpty(tab_bv);
            bottom_box = uix.VBox( 'Parent', tab_bv, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            rr_box = uix.VBox( 'Parent', bottom_box, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);

            uicontrol('Parent', rr_box, ...
                'Style', 'Text', ...
                'HorizontalAlignment', 'left', ...
                'String', 'Resource tree inspector:', ... %  when a center have missing resources (e.g. iono, vmf, ...) default values are used
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'ForegroundColor', Core_UI.BLACK, ...
                'FontSize', Core_UI.getFontSize(8));
             
            Core_UI.insertEmpty(bottom_box);
            
            dir_box = uix.VBox( 'Parent', bottom_box, ...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            bottom_box.Heights = [-1 5 225];
                         
            [~, this.edit_texts{end+1}, this.edit_texts{end+2}] = Core_UI.insertDirFileBox(dir_box, 'Geoid local path', 'geoid_dir', 'geoid_name', @this.onEditChange, [100 -3 5 -1 25]);
            [~, this.edit_texts{end+1}, this.edit_texts{end+2}] = Core_UI.insertDirFileBox(dir_box, 'CRX path', 'crx_dir', 'crx_name', @this.onEditChange, [100 -3 5 -1 25]);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(dir_box, 'Eph local dir', 'eph_dir', @this.onEditChange, [100 -1 25]);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(dir_box, 'Clk local dir', 'clk_dir', @this.onEditChange, [100 -1 25]);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(dir_box, 'ERP local dir', 'erp_dir', @this.onEditChange, [100 -1 25]);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(dir_box, 'IONO local dir', 'iono_dir', @this.onEditChange, [100 -1 25]);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(dir_box, 'IGRF local dir', 'igrf_dir', @this.onEditChange, [100 -1 25]);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(dir_box, 'DCB local dir', 'dcb_dir', @this.onEditChange, [100 -1 25]);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(dir_box, 'VMF local dir', 'vmf_dir', @this.onEditChange, [100 -1 25]);
            [~, this.edit_texts{end + 1}] = Core_UI.insertDirBox(dir_box, 'ATM local dir', 'atm_load_dir', @this.onEditChange, [100 -1 25]);

            this.j_rrini = com.mathworks.widgets.SyntaxTextPane;
            codeType = this.j_rrini.M_MIME_TYPE;  % j_settings.contentType='text/m-MATLAB'
            this.j_rrini.setContentType(codeType);
            try
                str = r_man.centerToString(this.state.getRemoteCenter);
                str = strrep(['% ' str], char(10), [char(10) '% ']);
            catch
                str = sprintf('[!!] Resource file missing:\n"%s"\nnot found\n\ngoGPS may not work properly', this.state.getRemoteSourceFile);
            end
            
            this.j_rrini.setText(str);
            this.j_rrini.setEditable(0)
            % Create the ScrollPanel containing the widget
            j_scroll_rri = com.mathworks.mwswing.MJScrollPane(this.j_rrini);
            % Inject edit box with the Java Scroll Pane into the main_window
            javacomponent(j_scroll_rri, [1 1 1 1], rr_box);
            rr_box. Heights = [18 -1];
            tab_bv.Heights = [15 5 20 18 18 18 1 -1];
            this.uip.tab_rr = tab;            
        end
        
        function insertOldRemoteResource(this, container)
            tab = uix.Grid('Parent', container);
            
            tab_bv = uix.VBox( 'Parent', tab, ...
                'Spacing', 5, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            uicontrol('Parent', tab_bv, ...
                'Style', 'Text', ...
                'String', 'Remote Resources ini file - not editable from GUI', ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'ForegroundColor', 0 * ones(3, 1), ...
                'FontName', 'arial', ...
                'FontSize', Core_UI.getFontSize(10), ...
                'FontWeight', 'bold');
            
            uicontrol('Parent', tab_bv, ...
                'Style', 'Text', ...
                'String', this.state.getRemoteSourceFile, ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG, ...
                'ForegroundColor', 0.3 * ones(3, 1), ...
                'FontName', 'arial', ...
                'FontSize', Core_UI.getFontSize(8));
            
            j_rrini = com.mathworks.widgets.SyntaxTextPane;
            codeType = j_rrini.M_MIME_TYPE;  % j_settings.contentType='text/m-MATLAB'
            j_rrini.setContentType(codeType);
            try
                file_name = this.state.getRemoteSourceFile;
                fid = fopen(file_name);
                str = fread(fid, '*char')';
                str = strrep(str,'#','%');
                fclose(fid);
            catch
                str = sprintf('[!!] Resource file missing:\n"%s"\nnot found\n\ngoGPS may not work properly', this.state.getRemoteSourceFile);
            end
            
            j_rrini.setText(str);
            j_rrini.setEditable(0)
            % Create the ScrollPanel containing the widget
            j_scroll_rri = com.mathworks.mwswing.MJScrollPane(j_rrini);
            % Inject edit box with the Java Scroll Pane into the main_window
            javacomponent(j_scroll_rri, [1 1 1 1], tab_bv);
            
            tab_bv.Heights = [20 15 -1];
            this.uip.tab_rr = tab;
            
        end
        
        function insertSessionInfo(this, container)
            session_bg = Core_UI.DARK_GRAY_BG;
            %session_p = uix.Panel('Parent', container, ...
            %    'Padding', 0, ...
            %    'BackgroundColor', session_bg);
            this.session_info = uix.VBox('Parent', container, ...
                'Padding', 0, ...
                'BackgroundColor', session_bg);
            
            v_text = uix.VBox( 'Parent', this.session_info, ...
                'Padding', 5, ...
                'BackgroundColor', session_bg);
            Core_UI.insertEmpty(v_text, session_bg);
            
            h_title = uix.HBox( 'Parent', v_text, ...
                'BackgroundColor', Core_UI.DARK_GRAY_BG);
            list_title = uicontrol('Parent', h_title, ...
                'Style', 'Text', ...
                'String', 'Session', ...
                'ForegroundColor', Core_UI.WHITE, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'FontWeight', 'bold', ...
                'BackgroundColor', session_bg);
            Core_UI.insertEmpty(h_title, session_bg);
            check_rec = uicontrol( 'Parent', h_title, ...
                'String', 'Check', ...
                'Callback', @this.onSessionSummaryCheck);
            
            Core_UI.insertEmpty(v_text, session_bg);
            v_text.Heights = [5, 23, -1];
            Core_UI.insertHBarDark(this.session_info);
            sss_g = uix.VBox('Parent', this.session_info, ...
                'Padding', 0, ...
                'BackgroundColor', session_bg);
            
            this.session_summary.start = uicontrol('Parent', sss_g, ...
                'Style', 'Text', ...
                'String', ' -- ', ...
                'ForegroundColor', Core_UI.WHITE, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'BackgroundColor', session_bg);
            Core_UI.insertEmpty(sss_g, session_bg);           
            this.session_summary.stop = uicontrol('Parent', sss_g, ...
                'Style', 'Text', ...
                'String', ' -- ', ...
                'ForegroundColor', Core_UI.WHITE, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'BackgroundColor', session_bg);
            Core_UI.insertEmpty(sss_g, session_bg);           
            this.session_summary.size = uicontrol('Parent', sss_g, ...
                'Style', 'Text', ...
                'String', ' -- ', ...
                'ForegroundColor', Core_UI.WHITE, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'BackgroundColor', session_bg);
            
            % % button sync => not used autp-sync on
            % but_session = uix.HButtonBox( 'Parent', this.session_info, ...
            %     'Padding', 5, ...
            %     'Spacing', 5, ...
            %     'HorizontalAlignment', 'right', ...
            %     'ButtonSize', [120 20], ...
            %     'BackgroundColor', 0.14 * [1 1 1]);
            %
            % save_but = uicontrol( 'Parent', but_session, ...
            %     'String', 'Sync Session UI => INI', ...
            %     'Callback', @this.onSessionChange);
            %
            % this.session_info.Heights = [26 2 5 50 30];
            this.session_info.Heights = [30 5 165];
            sss_g.Heights = [55 5 55 5 55];
        end
        
        function insertRecList(this, container)
            this.info_g = uix.VBox('Parent', container, ...
                'Padding', 0, ...
                'BackgroundColor', Core_UI.DARK_GRAY_BG);
            
            v_text = uix.VBox( 'Parent', this.info_g, ...
                'Padding', 5, ...
                'BackgroundColor', Core_UI.DARK_GRAY_BG);
            Core_UI.insertEmpty(v_text, Core_UI.DARK_GRAY_BG);
            h_title = uix.HBox( 'Parent', v_text, ...
                'BackgroundColor', Core_UI.DARK_GRAY_BG);
            list_title = uicontrol('Parent', h_title, ...
                'Style', 'Text', ...
                'String', 'Receiver List', ...
                'ForegroundColor', Core_UI.WHITE, ...
                'HorizontalAlignment', 'left', ...
                'FontSize', Core_UI.getFontSize(9), ...
                'FontWeight', 'bold', ...
                'BackgroundColor', Core_UI.DARK_GRAY_BG);
            Core_UI.insertEmpty(h_title, Core_UI.DARK_GRAY_BG);
            
            check_rec = uicontrol( 'Parent', h_title, ...
                'String', 'Check', ...
                'Callback', @this.updateAndCheckRecList);
            
            Core_UI.insertEmpty(h_title, Core_UI.DARK_GRAY_BG);
            
            plot_rec = uicontrol( 'Parent', h_title, ...
                'String', 'Plot', ...
                'Callback', @this.updateAndPlotRecList);

            h_title.Widths = [95 -1 50  -1 40];
            
            Core_UI.insertEmpty(v_text, Core_UI.DARK_GRAY_BG);
            
            v_text.Heights = [5, 23, -1];
            
            rec_g = uix.Grid('Parent', this.info_g, ...
                'Padding', 0, ...
                'BackgroundColor', Core_UI.DARK_GRAY_BG);
            
            this.rec_tbl = uitable('Parent', rec_g);
            this.rec_tbl.RowName = {}; 
            this.rec_tbl.ColumnName = {'N'; 'Name'; 'OK'; 'KO'};
            colTypes = {'char', 'char', 'short g', 'short g'};
            this.rec_tbl.ColumnFormat = colTypes;
            this.rec_tbl.ColumnEditable = [false false false false];
            this.rec_tbl.ColumnWidth = {45, 45, 45, 45};

            this.info_g.Heights = [35 -1];
            % this.updateRecList(); % this is done at the end of interface loading
        end
        
        function j_ini = insertTabAdvanced(this, container)
            tab = uix.Grid('Parent', container);
            
            com_box = Core_UI.insertPanelLight(tab, 'Parallelism');
            [~, this.edit_texts{end+1}] = Core_UI.insertDirBox(com_box, 'Communication dir', 'com_dir', @this.onEditChange, [160 -1 25]);

            settings_box = Core_UI.insertPanelLight(tab, 'Raw settings file');
            setting_grid =  uix.HBox('Parent', settings_box, ...
                    'Spacing', 5, ...
                    'BackgroundColor', Core_UI.LIGHT_GRAY_BG);

            
            j_ini = com.mathworks.widgets.SyntaxTextPane;
            codeType = j_ini.M_MIME_TYPE;  % j_settings.contentType='text/m-MATLAB'
            j_ini.setContentType(codeType);
            str = strrep(strCell2Str(this.state.export(), 10),'#','%');
            j_ini.setText(str);
            % Create the ScrollPanel containing the widget
            j_scroll_settings = com.mathworks.mwswing.MJScrollPane(j_ini);
            % Inject edit box with the Java Scroll Pane into the main_window
            [panel_j, panel_h] = javacomponent(j_scroll_settings, [1 1 1 1], setting_grid);
            
            set(j_ini, 'FocusLostCallback', @this.refreshIni);
            set(j_ini, 'FocusGainedCallback', @this.refreshIni);
            
            tab1_bvr = uix.VButtonBox( 'Parent', setting_grid, ...
                'Spacing', 5, ...
                'VerticalAlignment', 'top', ...
                'HorizontalAlignment', 'center', ...
                'ButtonSize', [120 20], ...
                'BackgroundColor', Core_UI.LIGHT_GRAY_BG);
            
            refresh_but = uicontrol( 'Parent', tab1_bvr, ...
                'String', 'Refresh INI => UI', ...
                'Callback', @this.refreshIni);
            
            check_rec = uicontrol( 'Parent', tab1_bvr, ...
                'String', 'Check receiver files', ...
                'Callback', @this.updateAndCheckRecList);
            
            setting_grid.Widths = [-1 128];
            tab.Heights = [50 -1];
        end
    end
    %% METHODS getters
    % ==================================================================================================================================================
    methods
        function ok_go = isGo(this)
            ok_go = this.ok_go;
        end
    end
    %% METHODS UI getters
    % ==================================================================================================================================================
    methods
        function [sss_start, sss_stop, validity_check] = getSessionsLimits(this)
            % get Start session and stop from UI
            % check validity if sss_start > sss_stop then stop = start
            %
            % SYNTAX:
            %   [sss_start, sss_stop, validity_check] = getSessionLimits(this)
            %
            state = Core.getCurrentSettings();
            validity_check = true;
            
            date = this.ui_sss_start.Children(2).JavaPeer.getDate;
            if isempty(date)
                sss_start = state.getSessionsStartExt;
            else
                sss_start = GPS_Time([date.getYear+1900 (date.getMonth + 1) date.getDate 0 0 0]);
            end
            hh_mm_ss = this.ui_sss_start.Children(1).Children(1).String;
            if ~isempty(hh_mm_ss)
                time_parts = regexp(hh_mm_ss,'(?<hour>\d+):(?<minute>\d+):(?<second>\d+)','names');
                if isempty(time_parts)
                    time_parts = struct('hour', '00', 'minute', '00', 'second', '00');
                end
                sss_start.addSeconds(str2num(time_parts.hour)*3600 + str2num(time_parts.minute)*60 + str2num(time_parts.second));
                this.ui_sss_start.Children(1).Children(1).String = sss_start.toString('HH:MM:SS');
                date = this.ui_sss_stop.Children(2).JavaPeer.getDate;
            end
            if isempty(date)
                sss_stop = state.getSessionsStopExt;
            else
                sss_stop = GPS_Time([date.getYear+1900 (date.getMonth + 1) date.getDate 00 00 00]);
            end
            hh_mm_ss = this.ui_sss_stop.Children(1).Children(1).String;
            if ~isempty(hh_mm_ss)
                time_parts = regexp(hh_mm_ss,'(?<hour>\d+):(?<minute>\d+):(?<second>\d+)','names');
                if isempty(time_parts)
                    time_parts = struct('hour', '23', 'minute', '59', 'second', '59');
                end
                sss_stop.addSeconds(str2num(time_parts.hour)*3600 + str2num(time_parts.minute)*60 + str2num(time_parts.second));
                this.ui_sss_stop.Children(1).Children(1).String = sss_stop.toString('HH:MM:SS');
            end
            if sss_stop <= sss_start
                validity_check = false;
                sss_stop = GPS_Time(floor(sss_start.getMatlabTime) + 86399/86400);
                this.ui_sss_stop.Children(1).Children(1).String = sss_stop.toString('HH:MM:SS');
            end
        end
    end    
    %% METHODS EVENTS
    % ==================================================================================================================================================
    methods (Access = public)
        function onSessionChange(this, caller, event)
            % Manage the event of session modification (UI)
            %
            % SYNTAX:
            %   this.onSessionChange()
            %
            [sss_start, sss_stop, validity_check] = getSessionsLimits(this);
            
            if ~validity_check
                this.ui_sss_stop.Children(2).JavaPeer.setDate(java.util.Date(sss_stop.toString('yyyy/mm/dd')));
            end
            
            state = Core.getCurrentSettings();
            status_change = false;
            if sss_start - state.getSessionsStart() ~= 0
                status_change = true;
                state.setSessionStart(sss_start);
            end
            if sss_stop - state.getSessionsStop() ~= 0
                status_change = true;
                state.setSessionStop(sss_stop);
            end
            if status_change
                this.updateINI();
                this.updateRecList();
                this.updateSessionSummary()
                this.updateSessionGUI();
            end
        end       
        
        function onCheckBoxConstChange(this, caller, event)
            % if the check box of one constalelation is ticked tick all the frequency of the constallation and call thei events
            this.onCheckBoxCCChange(caller, event);
            const = Constellation_Collector.constToAbb(caller.String);
            for i = 1 : length(this.check_boxes)
                if ~isempty(strfind(this.check_boxes{i}.UserData, [const '_']))
                    this.check_boxes{i}.Value = caller.Value;
                    this.onCheckBoxCCChange(this.check_boxes{i}, []); % <- call the event listener 
                end
            end
        end       
        
        function onCheckBoxCCChange(this, caller, event)
            if ~isempty(strfind(caller.UserData,'is_active'))
                active_list = this.state.cc.getActive();
                num = find(this.state.cc.SYS_C == caller.UserData(1));
                active_list(num) = caller.Value;
                this.state.cc.setActive(active_list);
                this.updateINI();
            else
                if caller.Value  % set the constellation to active too
                    active_list = this.state.cc.getActive();
                    sys_c = Constellation_Collector.abbToSysC(caller.UserData(1:3));
                    num = find(this.state.cc.SYS_C == sys_c);
                    active_list(num) = caller.Value;
                    this.state.cc.setActive(active_list);
                    for i = 1 : length(this.check_boxes)
                        if ~isempty(strfind(this.check_boxes{i}.UserData, [sys_c '_is_active']))
                            this.check_boxes{i}.Value = caller.Value;
                        end
                    end
                end
                
                sys_SS = this.state.cc.getSys(Constellation_Collector.abbToSysC(caller.UserData(1:3)));
                idx = find(sys_SS.CODE_RIN3_2BAND ==  caller.String(3));
                sys_SS.setFlagF(idx,caller.Value);
                this.updateINI();
            end
            
        end
        
        function onSSSCheckBoxChange(this, caller, event)
            this.onCheckBoxChange(caller, event)
            this.updateSessionSummary();
            this.updateSessionGUI();
        end
    
        function onCheckBoxChange(this, caller, event)
            this.state.setProperty(caller.UserData, caller.Value);
            this.updateINI();
            this.updateCheckBoxFromState(); % refresh duplicated checkboxes
        end
        
        function onPopUpChange(this, caller, event)
            if isprop(this.state,[upper(caller.UserData) '_UI2INI'])
                value = this.state.([upper(caller.UserData) '_UI2INI'])(caller.Value);
            else
                value = caller.Value;
            end
            this.state.setProperty(caller.UserData, value);
            this.updateINI();
        end
        
        function onResourcesPopUpChange(this, caller, event)
            
            if strcmp(caller.UserData, 'selected_center')
                % Particular case selected_center is in GUI with full description of the center
                % Use caller.Value and r_man.getCenterList();
                r_man = Remote_Resource_Manager.getInstance();
                
                % read current center
                [center_list, center_ss] = r_man.getCenterList();
                this.state.setProperty(caller.UserData, center_list{caller.Value});
            else
                this.state.setProperty(caller.UserData, caller.String(caller.Value));
            end
            
            % Set resources preferences
            r_man = Remote_Resource_Manager.getInstance();
            
            % Update Iono Preferences
            available_iono = r_man.getIonoType(this.state.getRemoteCenter());
            flag_preferred_iono = true(4,1);
            for i = 1 : 4
                this.ripref{i}.Enable = iif(available_iono(i), 'on', 'off');
                flag_preferred_iono(i) = available_iono(i) && logical(this.ripref{i}.Value);
            end
            this.state.setPreferredIono(flag_preferred_iono)
            
            % Update Orbit Preferences
            available_orbit = r_man.getOrbitType(this.state.getRemoteCenter());
            flag_preferred_orbit = true(4,1);
            for i = 1 : 4
                this.ropref{i}.Enable = iif(available_orbit(i), 'on', 'off');
                flag_preferred_orbit(i) = available_orbit(i) && logical(this.ropref{i}.Value);
            end
            this.state.setPreferredOrbit(flag_preferred_orbit)
            
            this.updateINI();
            this.updateResourcePopUpsState();
        end
        
        function onResourcesPrefChange(this, caller, event)
            % Set resources preferences          
            r_man = Remote_Resource_Manager.getInstance();

            if strcmp(caller.UserData(1:4), 'iono')
                % Update Iono Preferences
                available_iono = r_man.getIonoType(this.state.getRemoteCenter());
                flag_preferred_iono = true(4,1);
                for i = 1 : 4
                    flag_preferred_iono(i) = available_iono(i) && logical(this.ripref{i}.Value);
                end
                this.state.setPreferredIono(flag_preferred_iono)
            else
                % Update Orbit Preferences
                available_orbit = r_man.getOrbitType(this.state.getRemoteCenter());
                flag_preferred_orbit = true(4,1);
                for i = 1 : 4
                    flag_preferred_orbit(i) = available_orbit(i) && logical(this.ropref{i}.Value);
                end
                this.state.setPreferredOrbit(flag_preferred_orbit)
            end
                                    
            this.updateINI();
            this.updateResourcePopUpsState();
        end
        
        function onEditChange(this, caller, event)
            prop = this.state.getProperty(caller.UserData);
            if ~isnumeric(prop)
                this.state.setProperty(caller.UserData, caller.String);
            else
                this.state.setProperty(caller.UserData, str2num(caller.String));
            end
            
            this.state.check();
            caller.String = this.state.getProperty(caller.UserData);            
            this.updateINI();
            
            if strcmp(caller.UserData, 'crd_name') || strcmp(caller.UserData, 'crd_dir')
                rf = Core.getReferenceFrame;
                rf.init(this.state.getCrdFile);
                this.updateCooTable();
            end
            if strcmp(caller.UserData, 'obs_name') || strcmp(caller.UserData, 'obs_dir')
                this.updateRecList()
            end
        end
        
        function onEditArrayChange(this, caller, event)
            prop = this.state.getProperty(caller.UserData);
            n_child = length(caller.Parent.Children);
            array = [];
            for i = n_child : -1 : 1
                child =  caller.Parent.Children(i);
                if strcmp(child.Style, 'edit')
                    val = str2num(child.String);
                    if isempty(val)
                        val =0;
                    end
                    array = [array val];
                end
            end
            this.state.setProperty(caller.UserData, array);
            this.state.check();
            this.updateEditArrayFromState(caller.Parent);
            this.updateINI();
        end
        
        function onTabChange(this, caller, event)
            if event.NewValue == 1
                if ~isempty(this.j_settings)
                    try
                        str = strrep(strCell2Str(this.state.export(), 10),'#','%');
                        this.j_settings.setText(str);
                    catch ex
                        this.log.addWarning(sprintf('I cannot update j_settings\n%s', ex.message));
                    end
                else
                    % Check is always needed
                    this.state.check()
                    % this.log.addWarning('Warning invalid config can not updating j_settings');
                end
            end
        end
        
        function refreshIni(this, caller, event)
            txt = textscan(strrep(char(this.j_settings.getText()),'%','#'),'%s','Delimiter', '\n');
            this.state.import(Ini_Manager(txt{1}));
            this.updateUI();
        end
        
        function refreshCmdList(this, caller, event)
            txt = char(this.j_cmd.getText());
            if ~isempty(txt)
                txt = textscan(strrep(txt,'%','#'),'%s','Delimiter', '\n');
                this.state.importPlainCommands(txt{1});
            else
                this.state.importPlainCommands('');
            end
            this.updateUI();
        end
        
        function updateINI(this)
            if ~isempty(this.w_main) && isvalid(this.w_main)
                this.w_main.Name = sprintf('%s @ %s', this.state.getPrjName, this.state.getHomeDir);
                
                try
                    str = strrep(strCell2Str(this.state.export(), 10),'#','%');
                    if ~strcmp(str, char(this.j_settings.getText()))
                        this.j_settings.setText(str);
                    end
                catch ex
                    % Check is always needed
                    this.state.check()
                    this.log.addWarning(sprintf('I cannot update j_settings\n%s', ex.message));
                end
            end
        end
        
        function updateCmdList(this)
            if ~isempty(this.w_main) && isvalid(this.w_main)
                if this.j_cmd.isValid
                    str = strrep(strCell2Str(this.state.exportCmdList(), 10),'#','%');
                    if ~strcmp(str, char(this.j_cmd.getText()))
                        this.j_cmd.setText(str);
                    end
                end
            end
        end
        
        function updateSessionFromState(this, caller, event)
            state = Core.getCurrentSettings();
            this.ui_sss_start.Children(2).JavaPeer.setDate(java.util.Date(state.sss_date_start.toString('yyyy/mm/dd')));
            this.ui_sss_start.Children(1).Children(1).String = state.sss_date_start.toString('HH:MM:SS');
            %this.ui_sss_start.setDate(java.util.Date(state.sss_date_start.toString('yyyy/mm/dd')));
            this.ui_sss_stop.Children(2).JavaPeer.setDate(java.util.Date(state.sss_date_stop.toString('yyyy/mm/dd')));
            this.ui_sss_stop.Children(1).Children(1).String = state.sss_date_stop.toString('HH:MM:SS');
            %this.ui_sss_stop.setDate(java.util.Date(state.sss_date_stop.toString('yyyy/mm/dd')));
        end
        
        function updateCCFromState(this)
            active = this.state.cc.getActive();
            sys_c = this.state.cc.SYS_C;
            for i = 1 : length(active)
                this.setCheckBox([sys_c(i) '_is_active'], active(i));
                if active(i)
                    ss = this.state.cc.getSys(sys_c(i));
                    for j = 1: length( ss.flag_f)
                        f = ss.flag_f(j);
                        this.setCheckBox([Constellation_Collector.sysCToAbb(sys_c(i)) '_' Constellation_Collector.rin3ToBand(['L' ss.CODE_RIN3_2BAND(j) ], sys_c(i))], f);
                    end
                end
            end
        end
        
        function updateCheckBoxFromState(this)
            for i = 1 : length(this.check_boxes)
                value = this.state.getProperty(this.check_boxes{i}.UserData);
                if ~isempty(value)
                    this.check_boxes{i}.Value = double(value(1));
                end
            end
        end
        
        function updateEditFromState(this)
            for i = 1 : length(this.edit_texts)
                value = this.state.getProperty(this.edit_texts{i}.UserData);
                if ~isempty(value)
                    this.edit_texts{i}.String = value;
                end
            end
        end
        
        function updateEditArrayFromState(this, array_box)
            name_prop = array_box.UserData;
            array_value = this.state.getProperty(name_prop);
            n_child = length(array_box.Children);
            n_val = length(array_value);
            j = 1;
            for i = n_child : -1 : 1
                child =  array_box.Children(i);
                if strcmp(child.Style, 'edit')
                    child.String = array_value(min(j,n_val));
                    j = j+1;
                end
            end
        end
        
        function updateEditArraysFromState(this)
            for i = 1 : length(this.edit_texts_array)
                this.updateEditArrayFromState(this.edit_texts_array{i});
            end
        end
        
        function updatePopUpsState(this)
            for i = 1 : length(this.pop_ups)
                value = this.state.getProperty(this.pop_ups{i}.UserData);
                if ~isempty(value)
                    if  isprop(this.state,[upper(this.pop_ups{i}.UserData) '_UI2INI'])
                        this.pop_ups{i}.Value = find(this.state.([upper(this.pop_ups{i}.UserData) '_UI2INI']) == value);
                    else
                        this.pop_ups{i}.Value = value;
                    end
                end
            end
        end
        
        function updateResourcePopUpsState(this)
            % Getting current remote resource manager
            r_man = Remote_Resource_Manager.getInstance();
            
            % read current center
            [center_list, center_ss] = r_man.getCenterList();
            cur_center = this.state.getProperty(this.rpop_up.UserData);
            if isempty(cur_center)
                cur_center = {'default'};
            end
            value = 1;
            while (value < numel(center_list)) && ~strcmp(center_list{value}, cur_center)
                value = value + 1;
            end
            
            % display resources tree of the current center
            if ~isempty(value)
                this.rpop_up.Value = value;                
                try
                    str = r_man.centerToString(this.state.getRemoteCenter());
                    str = strrep(['% ' str], char(10), [char(10) '% ']);
                catch
                    str = sprintf('[!!] Resource file missing:\n"%s"\nnot found\n\ngoGPS may not work properly', this.state.getRemoteSourceFile);
                end
                this.j_rrini.setText(str);
            end
            
            % Update constellation Available for the center
            this.rpop_up.Parent.Children(2).String = sprintf('Center supporting constellations: "%s"', center_ss{value}); 
            
            % Update Orbit Preferences
            available_orbit = r_man.getOrbitType(cur_center{1});
            for i = 1 : 4
                this.ropref{i}.Enable = iif(available_orbit(i), 'on', 'off');
            end
            flag_preferred_orbit = this.state.getPreferredOrbit();
            for i = 1 : 4
                if available_orbit(i)
                    this.ropref{i}.Value = this.ropref{i}.Value | flag_preferred_orbit(i);
                end
            end
            
            % Update Iono Preferences
            available_iono = r_man.getIonoType(cur_center{1});
            for i = 1 : 4
                this.ripref{i}.Enable = iif(available_iono(i), 'on', 'off');
            end
            flag_preferred_iono = this.state.getPreferredIono();            
            for i = 1 : 4
                if available_iono(i)
                    this.ripref{i}.Value = this.ripref{i}.Value | flag_preferred_iono(i);
                end
            end
        end
        
        function onSessionSummaryCheck(this, caller, event)
            this.updateSessionSummary()
        end
        
        function updateAndCheckRecList(this, caller, event)
            % Get file name list
            state = Core.getCurrentSettings();
            state.updateObsFileName;
            n_rec = state.getRecCount;
            rec_path = state.getRecPath;
            str = '';
            
            color = round(Core_UI.getColor((1 : n_rec), n_rec) * 255);
            this.rec_tbl.Data = cell(1,4);
            for r = 1 : n_rec
                name = File_Name_Processor.getFileName(rec_path{r}{1});
                this.log.addMessage(sprintf('Checking %s', upper(name(1:4))));
                fr = File_Rinex(rec_path{r}, 100);
                n_ok = sum(fr.is_valid_list);
                n_ko = sum(~fr.is_valid_list);
                
                %this.rec_tbl.Data{r,1} = sprintf('%s style="font-weight: bold; font-size: 9px; color: rgb(%d, %d, %d); ">%d', '<html><tr><td width=9999 align=center ', color(r,1), color(r,2), color(r,3), r);
                this.rec_tbl.Data{r,1} = sprintf('%s style="font-weight: bold; font-size: 9px; color: #6666FF; ">%d', '<html><tr><td width=9999 align=center ', r);
                %this.rec_tbl.Data{r,2} = sprintf('%s style="font-weight: bold; font-size: 9px; color: rgb(%d, %d, %d); ">%s', '<html><tr><td width=9999 align=center ', color(r,1), color(r,2), color(r,3), upper(name(1:4)));
                this.rec_tbl.Data{r,2} = sprintf('%s style="font-weight: bold; font-size: 9px; color: #6666FF; ">%s', '<html><tr><td width=9999 align=center ', upper(name(1:4)));
                this.rec_tbl.Data{r,3} = n_ok;
                this.rec_tbl.Data{r,4} = n_ko;
            end
            this.log.addMessage('File availability checked');
        end
        
        function updateAndPlotRecList(this, caller, event)
            % Update file name list and plot daily availability of the files
            %
            % SYNTAX:
            %   this.updateAndPlotRecList
            
            % Get file name list
            state = Core.getCurrentSettings();
            state.updateObsFileName;
            n_rec = state.getRecCount;
            rec_path = state.getRecPath;
            fr = {};
            sta_name = {};
            for r = 1 : n_rec
                name = File_Name_Processor.getFileName(rec_path{r}{1});
                sta_name{end+1} = name(1:4);
                fr{r} = File_Rinex(rec_path{r}, 100);
                name = File_Name_Processor.getFileName(rec_path{r}{1});
            end
            
            sss_strt = this.state.getSessionsStartExt;
            sss_stop = this.state.getSessionsStopExt;
            for year = sss_strt.getDOY : sss_stop.getDOY
                y_strt = GPS_Time([year 1 1 0 0 0]);
                y_stop = GPS_Time([year+1 1 1 0 0 0]);
                weeks = (y_strt.getGpsWeek: y_stop.getGpsWeek)';
                week_time = GPS_Time.fromWeekDow(weeks,uint32(zeros(size(weeks))));
                week_time = week_time.getMatlabTime();
                months_time = datenum([year*ones(12,1) (1:12)' ones(12,1)]);
                
                y_strt = y_strt.getMatlabTime();
                y_stop = y_stop.getMatlabTime();
                f = figure; f.Name = sprintf('%03d: Daily RINEX File Availability %d', f.Number, year); f.NumberTitle = 'off'; hold on;
                line([week_time week_time], [0 n_rec+1],'Color',[0.9 0.9 0.9],'LineStyle',':');
                for r = 1 : n_rec
                    if sum(fr{r}.is_valid_list) > 0
                        central_time = GPS_Time.getMeanTime(fr{r}.first_epoch , fr{r}.last_epoch).getMatlabTime;
                        central_time = central_time(central_time >= y_strt & central_time <= y_stop);
                        line([y_strt y_stop], [r r],'Color',[0.6 0.6 0.6],'LineStyle',':', 'LineWidth', 1);
                        plot(central_time, r * ones(size(central_time)),'.', 'MarkerSize', 20, 'Color', Core_UI.getColor(r, n_rec));
                        if ~isempty(fr{r}.first_epoch) && ~isempty(fr{r}.last_epoch)
                            plot([fr{r}.first_epoch.getMatlabTime  fr{r}.last_epoch.getMatlabTime], r * [1 1], '-', 'Color', Core_UI.getColor(r, n_rec), 'LineWidth', 4);
                        end
                    end
                end
                x_lims = [max(sss_strt.getMatlabTime - 1, y_strt) min(sss_stop.getMatlabTime +1, y_stop)];
                months_time = months_time(months_time > x_lims(1) & months_time < x_lims(2));
                xlim(x_lims);
                ylim([0 n_rec + 1]);
                h = ylabel('STATION'); h.FontWeight = 'bold';
                ax = gca(); ax.YTick = 1:n_rec;
                ax.YTickLabel = sta_name;
                set(ax,'XGrid','on')
                title(sprintf('Rinex data avaliability %d',year));
                if numel(months_time) > 1
                ax.XTick = months_time;
                end
                datetick('x','dd/mm/yyyy HH','keepticks');
                ax.XTickLabelRotation = 45;
            end
            this.log.addMessage('File availability plotted');
        end
        
        function createNewProject(this, caller, event)
            % Create a new project            
            new = GUI_New_Project(this);
        end
        
        function about(this, caller, event)
            % Show About window
            new = GUI_About(this);
        end
        
        function setToPPP(this, caller, event)
            % Reset settings to values suggested for PPP troposphere estimation
            this.state.setToTropoPPP();
            this.updateUI();
        end
        
        function setToIonoFreeNET(this, caller, event)
            % Reset settings to values suggested for NET solution (long baselines iono-free)
            this.state.setToLongNET();
            this.updateUI();
        end
        
        function setToMediumNET(this, caller, event)
            % Reset settings to values suggested for NET solution (medium < 20km baselines no iono)
            this.state.setToMediumNET();
            this.updateUI();
        end
        
        function setToShortNET(this, caller, event)
            % Reset settings to values suggested for NET solution (short baselines no iono, no tropo)
            this.state.setToShortNET();
            this.updateUI();
        end
        
        function loadState(this, caller, event)
            % Load state settings
            
            config_dir = this.state.getHomeDir();
            if exist([config_dir filesep 'config'], 'dir')
                config_dir = [config_dir filesep 'config'];
            end
            % On MacOS this doesn't work anymore: [file_name, pathname] = uigetfile({'*.ini;','INI configuration file (*.ini)'; '*.mat;','state file goGPS < 0.5 (*.mat)'}, 'Choose file with saved settings', config_dir);
            [file_name, path_name] = uigetfile('*.ini', 'Choose file with saved settings', config_dir);
            
            if path_name ~= 0 % if the user pressed cancelled, then we exit this callback
                % get the extension (mat/ini):
                [~, ~, ext] = fileparts(file_name);
                
                % build the path name of the file to be loaded
                settings_file = fullfile(path_name, file_name);
                if strcmp(ext, '.ini')
                    this.state.importIniFile(settings_file);
                    Core.getReferenceFrame.init();
                    this.updateUI();
                else
                    this.log.addError('Unrecognized input file format!');
                end
            end
        end
        
        function saveState(this, caller, event)
            % Save state settings
            try
                txt = textscan(strrep(char(this.j_settings.getText()),'%','#'),'%s','Delimiter', '\n');
                this.state.import(Ini_Manager(txt{1}));
                this.state.save();
                this.updateUI();
                this.log.addMarkedMessage(sprintf('The file has been saved correctly on:\n     %s', this.state.getFilePath));
            catch ex
                this.log.addError(sprintf('Export failed!\n%s', ex.message));
            end
        end
        
        function saveAsState(this, caller, event)
            % Save As state settings
            config_dir = this.state.getHomeDir();
            if exist([config_dir filesep 'config'], 'dir')
                config_dir = [config_dir filesep 'config'];
            end
            [file_name, path_name] = uiputfile('*.ini','Save your settings', config_dir);
            
            if path_name == 0 %if the user pressed cancelled, then we exit this callback
                return
            end
            % build the path name of the save location
            settings_file = fullfile(path_name,file_name);
            try
                txt = textscan(strrep(char(this.j_settings.getText()),'%','#'),'%s','Delimiter', '\n');
                this.state.import(Ini_Manager(txt{1}));
                this.state.save(settings_file);
                this.updateUI();
                this.log.addMarkedMessage(sprintf('The file has been saved correctly on:\n     %s', settings_file));
            catch ex
                this.log.addError(sprintf('Export failed!\n%s', ex.message));
            end
        end
        
        function close(this, caller, event)
            close(this.w_main);
        end
        
        function go(this, caller, event)
            this.crd2RefFrame;
            this.log.addMarkedMessage('Starting computation!');
            
            this.state.save(Main_Settings.LAST_SETTINGS);
            close(this.w_main);
            this.ok_go = true;
        end
        
        function updateUI(this)
            if isvalid(this.w_main)
                this.updateINI();
                this.updateCooTable();
                this.updateCmdList();
                this.ini_path.String = this.state.getIniPath();
                this.updateSessionGUI();
                this.updateSessionSummary()
                this.updateSessionFromState();
                this.updateCCFromState();
                this.updateCheckBoxFromState();
                this.updateEditFromState();
                this.updateEditArraysFromState();
                this.updatePopUpsState();
                this.updateResourcePopUpsState();
                this.updateRecList();
            end
        end
        
        function updateRecList(this, flag_force)
            % Get file name list
            %
            % SYNTAX:
            %   this.updateRecList
            
            if nargin < 2 || isnan(flag_force)
                flag_force = false;
            end
            
            try
                this.rec_tbl.Data{1,1} = 1;
            catch ex
                % probably deleted object
                return
            end
            
            state = Core.getCurrentSettings();
            state.updateObsFileName;
            n_rec = state.getRecCount;
            rec_path = state.getRecPath;
            str = '';
            t0 = tic;
            
            % Get the maximum number of session to check
            max_sss = 0;
            for r = 1 : n_rec
                max_sss = max(max_sss, numel(rec_path{r}));
            end
            
            % If I need to check a lot of files use as a method to check
            % dir list, otherwise use existent cache
            persistent unique_dir dir_list 
            
            % If last check is older than 5 minutes ago
            % force_check
            persistent last_check
            if isempty(last_check) || (now - last_check) > (300 / 86400)
                last_check = now;                    
                flag_force = true;
            end
            
            available_files = [];
            % Get all the folders in wich the receivers are stored
            i = 0;
            for r = 1 : numel(rec_path)
                for s = 1 : numel(rec_path{r})
                    i = i + 1;
                    dir_path{i} = fileparts(rec_path{r}{s});
                end
            end
            
            dirty_cache = isempty(dir_list);
            if ~flag_force || (max_sss * n_rec > 366)
                % Check if the cache is for the same set of folders
                cur_unique_dir = unique(dir_path);
                if numel(unique_dir) == numel(cur_unique_dir)
                    for d = 1 : numel(unique_dir)
                        dirty_cache = dirty_cache || ~(strcmp(unique_dir{d}, cur_unique_dir{d}));
                    end
                else
                    dirty_cache = true;
                end
                if (dirty_cache)
                    Core.getLogger.addMessage('Dirty cache found for updateRecList', 100);
                end
                unique_dir = cur_unique_dir;
                clear cur_unique_dir;
                flag_force = dirty_cache;
            else                
                % Remove duplicates            
                unique_dir = unique(dir_path);
            end

            % If the number of files to check is > 366 or the cache is clean
            if (max_sss * n_rec > 366) || dirty_cache
                if flag_force
                    log = Core.getLogger;
                    log.addMessage(log.indent('Checking receivers data directories'));
                    for d = 1 : numel(unique_dir)
                        dir_list{d} = dir(fullfile(unique_dir{d}, '*.*'));
                    end
                end
                    
                for d = 1 : numel(unique_dir)                   
                    available_files = [available_files {dir_list{d}.name}];
                end
                available_files = [available_files{:}];
            end
            
            this.rec_tbl.Data = cell(1, 4);
            for r = 1 : n_rec
                if ~isempty(rec_path{r})
                    name = File_Name_Processor.getFileName(rec_path{r}{1});
                else
                    name = '    ';
                end
                %n_session = numel(rec_path{r});
                %if (n_session * n_rec) < 20
                %this.log.addMessage(sprintf('Checking %s', upper(name(1:4))));
                
                n_ok = 0; n_ko = 0;
                if ~isempty(available_files)
                    for s = 1 : numel(rec_path{r})
                        [~, file_name, ext] = fileparts(rec_path{r}{s});
                        if instr(available_files, [file_name ext])
                            n_ok = n_ok + 1;
                        else
                            n_ko = n_ko + 1;
                        end
                    end
                else
                    for s = 1 : numel(rec_path{r})
                        if (exist(rec_path{r}{s}, 'file') == 2)
                            n_ok = n_ok + 1;
                        else
                            n_ko = n_ko + 1;
                        end
                    end
                end
                
                %this.rec_tbl.Data{r,1} = sprintf('%s style="font-weight: bold; font-size: 9px; color: rgb(%d, %d, %d); ">%d', '<html><tr><td width=9999 align=center ', color(r,1), color(r,2), color(r,3), r);
                this.rec_tbl.Data{r,1} = sprintf('%s style="font-weight: bold; font-size: 9px; color: #6666FF; ">%d', '<html><tr><td width=9999 align=center ', r);
                %this.rec_tbl.Data{r,2} = sprintf('%s style="font-weight: bold; font-size: 9px; color: rgb(%d, %d, %d); ">%s', '<html><tr><td width=9999 align=center ', color(r,1), color(r,2), color(r,3), upper(name(1:4)));
                this.rec_tbl.Data{r,2} = sprintf('%s style="font-weight: bold; font-size: 9px; color: #6666FF; ">%s', '<html><tr><td width=9999 align=center ', upper(name(1:4)));
                this.rec_tbl.Data{r,3} = n_ok;
                this.rec_tbl.Data{r,4} = n_ko;
            end
                        
            if toc(t0) > 1
                this.log.addMessage('Receiver files checked');
            end
        end
        
        function updateSessionSummary(this)
            if ~isempty(this.session_summary.start)
                [~,doy_st] = this.state.sss_date_start.getDOY;
                week_st =  this.state.sss_date_start.getGpsWeek;
                [~,doy_en] = this.state.sss_date_stop.getDOY;
                week_en =  this.state.sss_date_stop.getGpsWeek;
                this.session_summary.start.String = sprintf( ...
                    ['Start Date/Time:\n',...
                    '  %s\n',...
                    '  week: %d doy: %d\n'], ...
                    this.state.sss_date_start.toString('yyyy-mm-dd  HH:MM:SS'), week_st, doy_st);
                this.session_summary.stop.String = sprintf( ...
                    ['End Date/Time:\n', ...
                    '  %s\n', ...
                    '  week: %d doy: %d\n'], ...
                    this.state.sss_date_stop.toString('yyyy-mm-dd  HH:MM:SS'), week_en, doy_en);
                if this.state.isRinexSession()
                    this.session_summary.size.String = sprintf( ...
                        ['Duration: rinex based\n', ...
                        'Buffer: none\n']);
                else
                    this.session_summary.size.String = sprintf( ...
                        ['Duration: %10d [s]\n', ...
                        'Buffer: %6d, %6d [s]\n'], ...
                        this.state.sss_duration, this.state.sss_buffer(1), this.state.sss_buffer(end));
                end
            end           
        end
        
        function updateSessionGUI(this)
            % enable disable fields
            ui_tspan = findobj(this.w_main, 'Tag', 'sss_duration');
            ui_buffer = findobj(this.w_main, 'Tag', 'sss_buffer');
            ui_smooth_tropo = findobj(this.w_main, 'Tag', 'sss_smooth');
            if this.state.isRinexSession()
                Core_UI.disableElement(ui_tspan);
                Core_UI.disableElement(ui_buffer);
                Core_UI.disableElement(ui_smooth_tropo);
            else
                Core_UI.enableElement(ui_tspan);
                Core_UI.enableElement(ui_buffer);                
                Core_UI.enableElement(ui_smooth_tropo);                
            end            
        end
        
        function setCheckBox(this, name_prop, value)
            for i = 1 : length(this.check_boxes)
                if this.check_boxes{i}.isvalid && strcmp(name_prop, this.check_boxes{i}.UserData)
                    this.check_boxes{i}.Value = double(value);
                end
            end
        end
    end
    
    methods
        function addGoMenu(this)
            this.menu.goGPS = uimenu(this.w_main, 'Label', 'goGPS');
            uimenu(this.menu.goGPS, ...
                'Label', 'About', ...
                'Callback', @this.about);            
            this.menu.options = uimenu(this.w_main, 'Label', 'Options');
            uimenu(this.menu.options, ...
                'Label', 'Set for PPP troposphere estimation', ...
                'Callback', @this.setToPPP);
            uimenu(this.menu.options, ...
                'Label', 'Set for NET solution (short baselines - ignore ionosphere - ignore troposphere)', ...
                'Callback', @this.setToShortNET);
            uimenu(this.menu.options, ...
                'Label', 'Set for NET solution (medium baselines < 20km - ignore ionosphere)', ...
                'Callback', @this.setToMediumNET);
            uimenu(this.menu.options, ...
                'Label', 'Set for NET solution (long baselines - iono-free)', ...
                'Callback', @this.setToIonoFreeNET);
            this.menu.project = uimenu(this.w_main, 'Label', 'Project');
            uimenu(this.menu.project, ...
                'Label', 'New', ...
                'Callback', @this.createNewProject);
            uimenu(this.menu.project, ...
                'Label', 'Load', ...
                'Callback', @this.loadState);
            uimenu(this.menu.project, ...
                'Label', 'Save', ...
                'Callback', @this.saveState);
            uimenu(this.menu.project, ...
                'Label', 'Save As', ...
                'Callback', @this.saveAsState);
        end
    end
end
