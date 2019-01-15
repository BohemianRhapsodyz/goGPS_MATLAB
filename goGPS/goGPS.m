function goGPS(ini_settings, use_gui, flag_online)
% SYNTAX:
%   goGPS(<ini_settings_file>, <use_gui =false>);
%
% INPUT:
%   ini_settings_file       path to the settings file
%   use_gui                 (0/1) flag to activate GUI editing of the settings
%                           default = 0 (false
%
% DESCRIPTION:
%   function launcher for goGPS
%   
% OUTPUT:
%   goGPS creates a singleton object, for debug purposes it is possible to obtain it typing:
%   core = Core.getInstance();
%
% EXAMPLE:
%   goGPS('../data/project/default_PPP/config/settings.ini');
%
% COMPILATION STRING:
%   tic; mcc -v -d ./bin/ -m goGPS -a tai-utc.dat -a cls.csv -a icpl.csv -a nals.csv -a napl.csv; toc;
%

%--- * --. --- --. .--. ... * ---------------------------------------------
%               ___ ___ ___
%     __ _ ___ / __| _ | __|
%    / _` / _ \ (_ |  _|__ \
%    \__, \___/\___|_| |___/
%    |___/                    v 1.0 beta 1
%
%--------------------------------------------------------------------------
%  Copyright (C) 2009-2018 Mirko Reguzzoni, Eugenio Realini
%  A list of all the historical goGPS contributors is in CREDITS.nfo
%--------------------------------------------------------------------------
%
%   This program is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation, either version 3 of the License, or
%   (at your option) any later version.
%
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.
%
%   You should have received a copy of the GNU General Public License
%   along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%--------------------------------------------------------------------------
% 01100111 01101111 01000111 01010000 01010011
%--------------------------------------------------------------------------

% if the plotting gets slower than usual, there might be problems with the
% Java garbage collector. In case, you can try to use the following
% command:
%
% java.lang.System.gc() %clear the Java garbage collector
%
% or:
%
% clear java

    %% Preparing execution and settings
    
    if (~isdeployed)
        % add all the subdirectories to the search path
        addPathGoGPS;
    end
    log = Logger.getInstance();
    log.disableFileOut();
    
    core = Core.getInstance(true); % Init Core
    
    if nargin >= 1 && ~isempty(ini_settings)
        core.import(ini_settings);
    end
    if nargin < 2 || isempty(use_gui)
        if isdeployed
            use_gui = true;
        else
            use_gui = true;
        end
    end
    
    if nargin < 3 || isempty(flag_online)
        flag_online = true;
    end
    
    % Every parameters when the application is deployed are strings
    if isdeployed
        if (ischar(use_gui) && (use_gui == '1'))
            use_gui = true;
        end
    end
    
    if use_gui
        ui = Core_UI.getInstance();
        ui.openGUI();
        
        if ~ui.isGo()
            return
        end
    end
        
    % Enable file logging
    if core.state.isLogOnFile()
        log.newLine();
        log.enableFileOut();
        log.setOutFile([core.state.getOutDir '/goGPS_run_${NOW}.log']); % <= to enable project logging
        % log.setOutFile(); <= to enable system logging (save into system folder)
        log.disableFileOut();
        fnp = File_Name_Processor();
        log.addMessage(sprintf('Logging to: %s\n', fnp.getRelDirPath(log.getFilePath, core.state.getHomeDir)));
        log.enableFileOut();
        log.addMessageToFile(Core_UI.getTextHeader());
        core.logCurrentSettings();
    end
    
    %% GO goGPS - here the computations start
    err_code = core.checkValidity();
    
    ok_go = err_code.go == 0; % here a check on the validity of the parameters should be done
    
    if ~ok_go
        log.addError('Invalid configuration found! Check the log messages above.');
    else
        
        if nargin >= 3 && ~isempty(flag_online)
            core.prepareProcessing(flag_online); % download important files
        else
            core.prepareProcessing();
        end
        
        ok_go = true; % here a check on the validity of the resources should be done
        
        if ok_go
            core.go(); % execute all
        end
        
        %% Closing all
        if ~use_gui
            close all;
        end
    end
    
    % Stop logging
    if core.state.isLogOnFile()
        log.disableFileOut();
        log.closeFile();
    end
    
    if ~isdeployed && ok_go
        % Do not export to workspace
        %log.addMessage('Execute the script "getResults", to load the object created during the processing');
        
        % Export into workspace
        rec = core.rec;
        assignin('base', 'core', core);
        assignin('base', 'rec', rec);
        
        log.addMarkedMessage('Now you should be able to see 2 variables in workspace:');
        log.addMessage(log.indent(' - core      the core processor object containing all the goGPS structures'));
        log.addMessage(log.indent(' - rec       the array of Receivers'));
    end
end

