%   CLASS GNSS_Station
% =========================================================================
%
%
%   Class to store receiver data (observations, and characteristics)
%
% EXAMPLE
%   trg = GNSS_Station();
%
% FOR A LIST OF CONSTANTs and METHODS use doc Receiver

%--------------------------------------------------------------------------
%               ___ ___ ___
%     __ _ ___ / __| _ | __|
%    / _` / _ \ (_ |  _|__ \
%    \__, \___/\___|_| |___/
%    |___/                    v 1.0 beta 2
%
%--------------------------------------------------------------------------
%  Copyright (C) 2009-2019 Mirko Reguzzoni, Eugenio Realini
%  Written by:       Andrea Gatti, Giulio Tagliaferro ...
%  Contributors:
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
%--------------------------------------------------------------------------
classdef GNSS_Station < handle
    properties (SetAccess = private, GetAccess = private)
        creation_time = GPS_Time(now); % object creation time
    end

    properties (SetAccess = public, GetAccess = public)
        marker_name    % marker name
        marker_type    % marker type
        number         % receiver number
        type           % receiver type
        version        % receiver version
        observer       % name of observer
        agency         % name of agency

        % ANTENNA ----------------------------------

        ant_serial     % antenna number
        ant_type       % antenna type
        ant_delta_h    % antenna height from the ground [m]
        ant_delta_en   % antenna east/north offset from the ground [m]

        static         % static or dynamic receiver 1: static 0: dynamic

        work           % handle to receiver Work Space
        old_work       % handle to the old Work Space used for repair CS (contains just few epochs)
        out            % handle to receiver outputs

        cc             % constallation collector contains information on the Constellation used
        state          % handle to the state object

        log            % handle to the log object
        w_bar          % handle to the wait bar object
    end

    % ==================================================================================================================================================
    %% PROPERTIES PLOTS
    % ==================================================================================================================================================

    properties
        slant_filter_win = 0; % used in some visualization represente the knot distance of splines used for filtering
    end

    % ==================================================================================================================================================
    %% METHODS INIT - CLEAN - RESET - REM - IMPORT - EXPORT
    % ==================================================================================================================================================
    methods
        function this = GNSS_Station(flag_static)
            % Creator method
            %
            % INPUT
            %   flag_static  flag is static [ boolean ]
            %
            % SYNTAX
            %   this = GNSS_Static(static)
            this.work = Receiver_Work_Space(this);
            this.out = Receiver_Output(this);
            if nargin >= 2 && ~isempty(flag_static)
                this.static = logical(flag_static);
            end
            this.init();
            this.resetInfo();
        end

        function importRinexLegacy(this, rinex_file_name, rate, sys_c_list)
            % Select the files to be imported
            %
            % INPUT
            %   rinex_file_name     path to a RINEX file
            %   rate                import rate
            %   sys_c_list          list of char specifing the satellite system to read
            %
            % SYNTAX
            %   this.importRinexLegacy(rinex_file_name, rate)
           if ~isempty(rinex_file_name) && (exist(rinex_file_name, 'file') == 2)
                this.work.rinex_file_name = rinex_file_name;
            else
                this.work.rinex_file_name = '';
            end
            this.work.load(rate, sys_c_list);
            this.work.out_start_time = this.work.time.first;
            this.work.out_stop_time = this.work.time.last;
        end

        function importRinexes(this, rin_list, time_start, time_stop, rate, sys_c_list)
            % Select the files to be imported
            %
            % INPUT
            %   rin_list      object containing the list of rinex to load [ File_Rinex ]
            %   time_start    first epoch to load [ GPS_Time ]
            %   time_stop     last epoch to load [ GPS_Time ]
            %   rate          import rate [s]
            %   sys_c_list          list of char specifing the satellite system to read
            %
            % SYNTAX
            %   this.importRinexes(rin_list, time_start, time_stop, rate)
            this.work.importRinexFileList(rin_list, time_start, time_stop, rate, sys_c_list);
        end

        function clearHandles(this)
            % Clear handles
            %
            % SYNTAX
            %   this.clearHandles();

            this.log = [];
            this.state = [];

            this.w_bar = [];
        end
        
        function initHandles(this)
            % Reload handles
            % 
            % SYNTAX
            %   this.initHandles
            
            this.log = Core.getLogger();
            this.state = Core.getState();

            this.w_bar = Go_Wait_Bar.getInstance();
        end
        
        function init(this)
            % Reset handles
            %
            % SYNTAX
            %   this.init();

            this.log = Core.getLogger();
            this.state = Core.getState();

            this.w_bar = Go_Wait_Bar.getInstance();
            this.work = Receiver_Work_Space(this);
        end

        function resetInfo(this)
            % Reset information about receiver (name, type, number...)
            %
            % SYNTAX
            %   this.reset()
            this.marker_name  = 'unknown';  % marker name
            this.marker_type  = '';       % marker type
            this.number   = '000';
            this.type     = 'unknown';
            this.version  = '000';
        end

        function resetWork(sta_list)
            % Reset handle to work object
            %
            % SYNTAX
            %   this.resetWork()
            for r = 1 : numel(sta_list)
                sta_list(r).work.resetWorkSpace();
                sta_list(r).old_work = Receiver_Work_Space(sta_list(r));
            end
        end

        function resetOut(sta_list)
            % Reset handle to output object
            %
            % SYNTAX
            %   this.resetOut()
            for r = 1 : numel(sta_list)
                sta_list(r).out = Receiver_Output(sta_list(r));
            end
        end

        function netPrePro(sta_list)
            % EXPERIMENTAL pre processing multi-receiver
            % Perform multi-receiver pre-processing
            %  - outlier detection,
            %  - realignment of "old" phases for ambiguity passing + repair
            %
            % INPUT
            %   sta_list    list of receiver
            %
            % SYNTAX
            %   sta_list.netProPro()

            realign_ph = true;
            out_det = true;

            show_fig = false;
            % Prepare data in a unique structure

            work_list = [sta_list(~sta_list.isEmptyWork_mr).work];
            if numel(work_list) > 1 && (show_fig || out_det)

                [~, id_rsync] = Receiver_Commons.getSyncTimeExpanded(work_list);
                id_rsync(any(isnan(zero2nan(id_rsync)')), :) = [];

                n_epochs = size(id_rsync, 1);
                n_rec = numel(work_list);

                clear dt_red ph_red id_ph_red
                for r = 1 : n_rec
                    work_list(r).keepBestTracking();
                    [dt_red{r}, ph_red{r}, id_ph_red{r}] = work_list(r).getReducedPhases();
                    dt_red{r} = dt_red{r}(id_rsync(:, r), :);
                    ph_red{r} = bsxfun(@rdivide, ph_red{r}(id_rsync(:, r), :), work_list(r).wl(id_ph_red{r})');
                end

                % Get all SS present in the receivers
                all_ss = unique([work_list.system]);
                for sys_c = all_ss
                    n_obs = 0;
                    prn_list = [];
                    bands = '';
                    % Each phase will be added
                    for r = 1 : n_rec
                        obs_code = work_list(r).getAvailableObsCode('L', sys_c);
                        bands = [bands; obs_code(:,2:3)];
                        n_obs = n_obs + size(obs_code, 1);
                        prn_list = unique([prn_list; work_list(r).prn(work_list(r).findObservableByFlag('L', sys_c))]);
                    end
                    n_sat = numel(prn_list);
                    tracking = unique(bands(:,2));
                    bands = unique(bands(:,1));
                    n_bands = numel(bands);

                    all_ph_red = zeros(n_epochs, n_sat * n_bands, n_rec);
                    all_dph_red = nan(n_rec, n_epochs, n_sat * n_bands);
                    for r = 1 : n_rec
                        id = work_list(r).findObservableByFlag('L', sys_c);
                        [id_ok, ~, id_red] = intersect(id, id_ph_red{r});
                        [~, ~, p_list] = intersect(work_list(r).prn(id_ok), prn_list);
                        [~, ~, b_list] = intersect(work_list(r).obs_code(id_ok, 2), bands);

                        sid = repmat(p_list, n_bands,1 ) + serialize(repmat(numel(prn_list) * (b_list - 1)', numel(p_list), 1)); %< -this only works if all band are available on all satellites, otherwise it will crash, to be fixed
                        all_ph_red(:, sid, r) = zero2nan(ph_red{r}(:, id_red));
                        tmp = Core_Utils.diffAndPred(all_ph_red(:, sid, r));
                        tmp = bsxfun(@minus, tmp, strongMean(tmp,0.95, 0.95, 2));
                        tmp(work_list(r).sat.outliers_ph_by_ph(id_rsync(:, r),:) | work_list(r).sat.cycle_slip_ph_by_ph(id_rsync(:, r),:)) = nan;
                        all_dph_red(r, :, sid) = zero2nan(permute(tmp, [3 1 2]));
                    end

                    if show_fig || out_det
                        % Estimate common term from data
                        ct = squeeze(median(all_dph_red, 1, 'omitnan'));
                        ct(sum(~isnan(zero2nan(all_dph_red))) <= 1) = 0;

                        id_even = squeeze(sum(~isnan(zero2nan(all_dph_red))) == 2);
                        if any(id_even(:))
                            % find the observation that is closer to zero
                            [tmp, id] = min(abs(zero2nan(all_dph_red)));
                            tmp_min = all_dph_red(id(:) + 2*(0 : (numel(ct) -1))');

                            % when I have 2 observations choose the observation closer to zero
                            ct(id_even) = tmp_min(id_even);
                        end
                        ct = nan2zero(ct);
                    end

                    if out_det
                        for r = 1 : n_rec
                            id = work_list(r).findObservableByFlag('L', sys_c);
                            [id_ok, ~, id_red] = intersect(id, id_ph_red{r});
                            [~, ~, p_list] = intersect(work_list(r).prn(id_ok), prn_list);
                            [~, ~, b_list] = intersect(work_list(r).obs_code(id_ok, 2), bands);

                            sid = p_list + numel(prn_list) * (b_list - 1);

                            sensor = abs((squeeze(all_dph_red(r,:,sid)) - ct(:, sid))  .* (abs(ct(:, sid)) > 0)) > 0.1;

                            % V0
                            % id_ph = work_list(r).findObservableByFlag('L', sys_c);
                            % for b = b_list'
                            %     for p = 1: numel(p_list)
                            %         sid = p + numel(prn_list) * (b - 1);
                            %
                            %         id_obs = work_list(r).findObservableByFlag(['L' bands(b)], sys_c, prn_list(p_list(p)));
                            %         [~, ~, ido] = intersect(id_obs, id_ph);
                            %         work_list(r).sat.outliers_ph_by_ph(id_rsync(:,r), ido) = work_list(r).sat.outliers_ph_by_ph(id_rsync(:,r), ido) | ;
                            %     end
                            % end

                            % V1 (improve V0)
                            id_ko = false(size(work_list(r).sat.outliers_ph_by_ph));
                            id_ko(id_rsync(:,r),:) = sensor;
                            work_list(r).addOutliers(id_ko, true);
                        end
                    end
                end

                % Realign phases with the past
                % (useful when work_list(r).state.flag_amb_pass)
                if realign_ph
                    for r = 1 : n_rec
                        if work_list(r).state.flag_amb_pass && ~isempty(work_list(r).parent.old_work) && ~work_list(r).parent.old_work.isEmpty
                            t_new = round(work_list(r).parent.work.time.getRefTime(work_list(r).parent.old_work.time.first.getMatlabTime) * 1e7) / 1e7;
                            t_old = round(work_list(r).parent.old_work.time.getRefTime(work_list(r).parent.old_work.time.first.getMatlabTime) * 1e7) / 1e7;
                            [~, id_new, id_old] = intersect(t_new, t_old);

                            if ~isempty(id_new)
                                [ph, wl, lid_ph] = work_list(r).getPhases();
                                tmp = ph - work_list(r).getSyntPhases;
                                id_ph = find(lid_ph);
                                for i = 1 : length(id_ph)
                                    [amb_off, old_ph, old_synt] = work_list(r).parent.old_work.getLastRepair(work_list(r).go_id(id_ph(i)), work_list(r).obs_code(id_ph(i),2:3));
                                    if ~isempty(old_ph)
                                        ph_diff = (tmp(id_new, i) / wl(i) - (old_ph(id_old) - old_synt(id_old)));
                                        amb_off_emp = median(round(ph_diff / work_list(r).state.getCycleSlipThr()), 'omitnan') * work_list(r).state.getCycleSlipThr;
                                        if ~isempty(amb_off_emp) && amb_off_emp ~= 0
                                            ph(:,i) = ph(:,i) - amb_off_emp * wl(i);
                                        end
                                    end
                                end
                                work_list(r).setPhases(ph, wl, lid_ph);
                            end
                        end
                    end
                end

                % plots
                if show_fig
                    for sys_c = all_ss

                        for r = 1 : n_rec
                            figure; plot(squeeze(all_dph_red(r,:,:)) - ct); title(sprintf('Receiver %d diff', r));
                            figure; clf;
                            [tmp, tmp_trend, tmp_jmp] = work_list(r).flattenPhases(squeeze(all_ph_red(:, :, r)) - cumsum(ct));
                            plot(all_ph_red(:, :, r) - tmp_trend + tmp_jmp - repmat(strongMean(all_ph_red(:, :, r) - tmp_trend + tmp_jmp), size(tmp_trend, 1), 1));
                            title(sprintf('Receiver (Possible Repair) %d full', r));
                            dockAllFigures;
                            figure; clf;
                            plot(all_ph_red(:, :, r) - tmp_trend - repmat(strongMean(all_ph_red(:, :, r) - tmp_trend), size(tmp_trend, 1), 1));
                            title(sprintf('Receiver %d full', r));
                            dockAllFigures;
                            try
                                ww = work_list(r).parent.old_work; ph_red = ww.getPhases() - ww.getSyntPhases(); figure; plot(ww.time.getMatlabTime, ph_red ./ ww.wl(1), '.-k')
                                ww = work_list(r); ph_red = ww.getPhases() - ww.getSyntPhases(); hold on; plot(ww.time.getMatlabTime, ph_red ./ ww.wl(1))
                            catch
                            end
                            dockAllFigures;
                        end
                    end
                end
            end
        end

        function exportMat(sta_list)
            % Export the receiver into a MATLAB file (work properties is not saved )
            %
            % SYNTAX
            %   sta_list.exportMat()

            for r = 1 : numel(sta_list)
                try
                    % Get time span of the receiver
                    time = sta_list(r).getTime().getEpoch([1 sta_list(r).getTime().length()]);
                    time.toUtc();

                    fname = fullfile(sta_list(r).state.getOutDir(), sprintf('full_%s-%s-%s-rec%04d%s', sta_list(r).marker_name, time.first.toString('yyyymmdd_HHMMSS'), time.last.toString('yyyymmdd_HHMMSS'), r, '.mat'));

                    rec = sta_list(r);
                    tmp_work = rec.work; % back-up current out
                    rec.work = Receiver_Work_Space(rec);
                    save(fname, 'rec');
                    rec.work = tmp_work;

                    rec.log.addStatusOk(sprintf('Receiver %s: %s', rec.getMarkerName4Ch, fname));
                catch ex
                    sta_list(r).log.addError(sprintf('saving Receiver %s in matlab format failed: %s', sta_list(r).getMarkerName4Ch, ex.message));
                end
            end
        end
    end
    % ==================================================================================================================================================
    %% METHODS GETTER - TIME
    % ==================================================================================================================================================

    methods
        % standard utility
        function toString(sta_list)
            % Display on screen information about the receiver
            %
            % INPUT
            %   sta_list    list of receivers
            %
            % SYNTAX
            %   this.toString(sta_list);
            for i = 1:length(sta_list)
                if ~isempty(sta_list(i))
                    fprintf('==================================================================================\n')
                    sta_list(i).log.addMarkedMessage(sprintf('Receiver %s\n Object created at %s', sta_list(i).getMarkerName(), sta_list(i).creation_time.toString));
                    fprintf('==================================================================================\n')

                    if ~sta_list(i).work.isEmpty()
                        sta_list(i).work.toString();
                    end
                    if ~sta_list(i).out.isEmpty()
                        sta_list(i).out.toString();
                    end
                end
            end
        end

        function cc = getCC(this)
            % Get Constellation collector
            %
            % SYNTAX
            %   cc = this.getCC()
            cc = Core.getState.getConstellationCollector;
        end
        
        function id = getStationId(sta_list, marker_name)
            % Given a marker_name get the sequencial id of a station
            %
            % INPUT
            %   sta_list      list of receivers
            %   marker_name   4 letter marker name
            %
            % SYNTAX
            %   id = getStationId(this, marker_name)
            marker4ch_list = '';
            for r = 1 : numel(sta_list)
                try
                    marker4ch_list(r, :) = char(sta_list(r).getMarkerName4Ch);
                catch
                    % the name is shorter or missing => ignore
                end
            end
            id = find(Core_Utils.code4Char2Num(upper(marker4ch_list)) == Core_Utils.code4Char2Num(upper(marker_name)));
        end

        function req_rec = get(sta_list, marker_name)
            % Get the receivers with a certain Marker name (case unsensitive)
            %
            % SYNTAX
            %   req_rec = sta_list.get(marker_name)
            req_rec = [];
            for r = 1 : size(sta_list,2)
                rec = sta_list(~sta_list(:,r).isEmpty_mr ,r);
                if not(rec.isEmpty)
                    if strcmpi(rec(1).getMarkerName, marker_name)
                        req_rec = [req_rec sta_list(:,r)]; %#ok<AGROW>
                    elseif strcmpi(rec(1).getMarkerName4Ch, marker_name)
                        req_rec = [req_rec sta_list(:,r)]; %#ok<AGROW>
                    end
                end
            end
        end

        function marker_name = getMarkerName(this)
            % Get the Marker name as specified in the RINEX file
            %
            % SYNTAX
            %   marker_name = getMarkerName(this)
            marker_name = this.marker_name;
            if isempty(marker_name)
                marker_name = this.getMarkerName4Ch();
            end
        end

        function printStationList(sta_list)
            % Print the list of station / markers
            %
            % SYNTAX
            %   sta_list.printStationList()
            log = Logger.getInstance();
            if numel(sta_list) > 0
                log.addMessage('List of available stations:');
                for r = 1 : numel(sta_list)
                    try
                        log.addMessage(sprintf('%4d) %s', r, char(sta_list(r).getMarkerName)));
                        marker4ch_list
                    catch
                        % the name is shorter or missing => ignore
                    end
                end
            end
        end

        function marker_name = getMarkerName4Ch(this)
            % Get the Marker name as specified in the file name
            % (first four characters)
            %
            % SYNTAX
            %   marker_name = getMarkerName4Ch(this)
            if ~isempty(this.work.rinex_file_name)
                marker_name = File_Name_Processor.getFileName(this.work.rinex_file_name);
            else
                marker_name = this.marker_name;
            end
            marker_name = marker_name(1 : min(4, length(marker_name)));
        end

        function out_prefix = getOutPrefix(this)
            % Get the name for exporting output (valid for dayly output)
            %   - marker name 4ch (from rinex file name)
            %   - 4 char year
            %   - 3 char doy
            %
            % SYNTAX
            %   out_prefix = this.getOutPrefix()
            if this.out.length == 0
                time = this.work.time.getCopy;
            else
                time = this.out.time.getCopy;
            end
            [year, doy] = time.getCentralTime.getDOY();
            out_prefix = sprintf('%s_%04d_%03d_', this.getMarkerName4Ch, year, doy);
        end

        function is_empty = isEmpty_mr(sta_list)
            % Return if the object does not cantain any observations (work) or results (out)
            %
            % SYNTAX
            %   is_empty = this.isEmpty_mr();
            %
            % SEE ALSO
            %   isEmptyOut_mr isEmptyWork_mr
            is_empty =  false(numel(sta_list), 1);
            for r = 1 : numel(sta_list)
                is_empty(r) =  sta_list(r).work.isEmpty() && sta_list(r).out.isEmpty();
            end
        end
        
        function has_phases = hasPhases_mr(sta_list)
            % Return if the object does not cantain any observations (work) or results (out)
            %
            % SYNTAX
            %   is_empty = this.isEmpty_mr();
            %
            % SEE ALSO
            %   isEmptyOut_mr isEmptyWork_mr
            has_phases = false(numel(sta_list), 1);
            for r = 1 : numel(sta_list)
                has_phases(r) =  ~sta_list(r).work.isEmpty() && sta_list(r).work.hasPhases();
            end
        end
        

        function is_empty = isEmptyWork_mr(sta_list)
            % Return if the object work does not cantains any observation
            %
            % SYNTAX
            %   is_empty = this.isEmptyWork_mr();
            %
            % SEE ALSO
            %   isEmpty_mr isEmptyOut_mr
            is_empty =  false(numel(sta_list), 1);
            for r = 1 : numel(sta_list)
                is_empty(r) =  sta_list(r).work.isEmpty();
            end
        end

        function is_empty = isEmptyOut_mr(sta_list)
            % Return if the object out does not cantains any results
            %
            % SYNTAX
            %   is_empty = this.isEmptyOut_mr();
            %
            % SEE ALSO
            %   isEmpty_mr isEmptyWork_mr
            is_empty =  false(numel(sta_list), 1);
            for r = 1 : numel(sta_list)
                is_empty(r) =  sta_list(r).out.isEmpty();
            end
        end

        function is_empty = isEmpty(this)
            % Return if the object does not cantains any observation
            %
            % SYNTAX
            %   is_empty = this.isEmpty();

            is_empty = isempty(this) || ((isempty(this.work) || this.work.isEmpty()) && (isempty(this.out) || this.out.isEmpty()));
        end

        function time = getTime(this)
            % return the time stored in the object out
            %
            % OUTPUT
            %   time     GPS_Time
            %
            % SYNTAX
            %   xyz = this.getTime()
            time = this.out.getTime();
        end

        function n_epo = getNumEpochs(sta_list)
            % Return the number of epochs stored in work
            %
            % SYNTAX
            %   len = this.getNumEpochs();
            n_epo =  zeros(numel(sta_list), 1);
            for r = 1 : numel(sta_list)
                n_epo(r) =  sta_list(r).work.time.length();
            end
            n_epo = sum(n_epo);
        end

        function n_sat = getMaxSat(sta_list, sys_c)
            % get the number of satellites stored in the object work
            %
            % SYNTAX
            %   n_sat = getNumSat(<sys_c>)
            n_sat = zeros(numel(sta_list),1);
            for r = 1 : size(sta_list, 2)
                rec(r) = sta_list(r);
                if nargin == 2
                    n_sat(r) = rec.work.getMaxSat(sys_c);
                elseif nargin == 1
                    n_sat(r) = rec.work.getMaxSat();
                end
            end
        end

        function n_sat = getMaxNumSat(sta_list, sys_c)
            % get the number of maximum theoretical satellites stored in the object
            %
            % SYNTAX
            %   n_sat = getMaxNumSat(<sys_c>)

            n_sat = zeros(numel(sta_list),1);
            for r = 1 : size(sta_list, 2)
                rec(r) = sta_list(r);
                if nargin == 2
                    n_sat(r) = rec.work.getMaxNumSat(sys_c);
                elseif nargin == 1
                    n_sat(r) = rec.work.getMaxNumSat();
                end
            end
        end

        function [time_lim_small, time_lim_large] = getWorkTimeSpan(this)
            % return a GPS_Time containing the first and last epoch stored in the Receiver
            %
            % OUTPUT
            %   time_lim_small     GPS_Time (first and last) epoch of the smaller interval
            %   time_lim_large     GPS_Time (first and last) epoch of the larger interval
            %
            % SYNTAX
            %   [time_lim_small, time_lim_large] = getWorkTimeSpan(this);
            %
            time_lim_small = this(1).work.time.first;
            tmp_small = this(1).work.time.last;
            time_lim_large = time_lim_small.getCopy;
            tmp_large = tmp_small.getCopy;
            for r = 2 : numel(this)
                if time_lim_small < this(r).work.time.first
                    time_lim_small = this(r).work.time.first;
                end
                if time_lim_large > this(r).work.time.first
                    time_lim_large = this(r).work.time.first;
                end

                if tmp_small > this(r).work.time.last
                    tmp_small = this(r).work.time.last;
                end
                if tmp_large < this(r).work.time.last
                    tmp_large = this(r).work.time.last;
                end
            end
            time_lim_small.append(tmp_small);
            time_lim_large.append(tmp_large);
        end

        function [time_lim_small, time_lim_large] = getOutTimeSpan(this)
            % return a GPS_Time containing the first and last epoch stored in the Receiver
            %
            % OUTPUT
            %   time_lim_small     GPS_Time (first and last) epoch of the smaller interval
            %   time_lim_large     GPS_Time (first and last) epoch of the larger interval
            %
            % SYNTAX
            %   [time_lim_small, time_lim_large] = getOutTimeSpan(this);
            %
            time_lim_small = this(1).out.time.first;
            tmp_small = this(1).out.time.last;
            time_lim_large = time_lim_small.getCopy;
            tmp_large = tmp_small.getCopy;
            for r = 2 : numel(this)
                if time_lim_small < this(r).out.time.first
                    time_lim_small = this(r).out.time.first;
                end
                if time_lim_large > this(r).out.time.first
                    time_lim_large = this(r).out.time.first;
                end

                if tmp_small > this(r).out.time.last
                    tmp_small = this(r).out.time.last;
                end
                if tmp_large < this(r).out.time.last
                    tmp_large = this(r).out.time.last;
                end
            end
            time_lim_small.append(tmp_small);
            time_lim_large.append(tmp_large);
        end

        function [rate] = getRate(this)
            % Get the rate of the output (or work if out is empty)
            %
            % SYNTAX
            %   rate = this.getRate();
            try
                if ~(isempty(this.out) || this.out.isEmpty)
                    rate = this.out.getTime.getRate;
                else
                    rate = nan;
                end
                if isnan(rate)
                    rate = this.work.getTime.getRate;
                end
            catch
                % if anything happen probably
                rate = nan;
            end
        end

        function coo = getPos(sta_list)
            % return the positions computed for the receiver
            %
            % OUTPUT
            %   coo     object array [ Coordinate ]
            %
            % SYNTAX
            %   coo = sta_list.getPos()
            for r = 1 : numel(sta_list)
                coo(r) = sta_list(r).out.getPos();
            end
        end

        function xyz = getPosXYZ(sta_list)
            % return the positions computed for the receiver
            %
            % OUTPUT
            %   xyz     XYZ coordinates cell array
            %
            % SYNTAX
            %   xyz = this.getPosENU()
            xyz = {};
            for r = 1 : numel(sta_list)
                xyz{r} = sta_list(r).out.getPosXYZ();
            end
        end

        function [xyz, p_time, sta_ok] = getPosXYZ_mr(sta_list)
            % return the positions computed for the receiver
            % multi_rec mode (synced)
            %
            % OUTPUT
            %   xyz     XYZ coordinates synced matrix (n_epoch, 3, n_rec)
            %
            % SYNTAX
            %   [xyz, p_time, sta_ok] = sta_list.getPosXYZ_mr()

            sta_ok = find(~sta_list.isEmptyOut_mr());
            [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(sta_list(sta_ok), [], true);

            id_ok = any(~isnan(id_sync),2);
            id_sync = id_sync(id_ok, :);
            p_time = p_time.getEpoch(id_ok);
            
            n_rec = numel(sta_list);
            xyz = nan(size(id_sync, 1), 3, n_rec);
            for r = 1 : numel(sta_ok)                
                xyz_rec = sta_list(sta_ok(r)).out.getPosXYZ();
                id_rec = id_sync(:,r);
                xyz(~isnan(id_rec), :, sta_ok(r)) = xyz_rec(id_rec(~isnan(id_rec)), :);
            end
        end

        function [dist_3d, xyz_dist] = getDistFrom(sta_list, rec_ref)
            % GeetDistance from reference station rec_ref
            %
            % SYNTAX:
            %   dist = getDistFrom(this, rec_ref)
            xyz = zero2nan(sta_list.getMedianPosXYZ);
            xyz_dist = bsxfun(@minus, xyz, rec_ref.getMedianPosXYZ);
            dist_3d = sqrt(sum(xyz_dist.^2, 2));
        end

        function enu = getPosENU(sta_list)
            % return the positions computed for the receiver
            %
            % OUTPUT
            %   enu     enu coordinates cell array
            %
            % SYNTAX
            %   enu = sta_list.getPosENU()
            for r = 1 : numel(sta_list)
                enu{r} = sta_list(r).out.getPosENU();
            end
        end

        function [enu, p_time, sta_ok] = getPosENU_mr(sta_list)
            % return the positions computed for n receivers
            % multi_rec mode (synced)
            %
            % OUTPUT
            %   enu     enu synced coordinates
            %
            % SYNTAX
            %   [enu, p_time, sta_ok] = sta_list.getPosENU_mr()
            
            sta_ok = find(~sta_list.isEmptyOut_mr());
            [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(sta_list(sta_ok), [], true);

            id_ok = any(~isnan(id_sync),2);
            id_sync = id_sync(id_ok, :);
            p_time = p_time.getEpoch(id_ok);
            
            n_rec = numel(sta_list);
            enu = nan(size(id_sync, 1), 3, n_rec);
            for r = 1 : numel(sta_ok)                
                enu_rec = sta_list(sta_ok(r)).out.getPosENU();
                id_rec = id_sync(:,r);
                enu(~isnan(id_rec), :, sta_ok(r)) = enu_rec(id_rec(~isnan(id_rec)), :);
            end            
        end

        function xyz = getMedianPosXYZ(this)
            % return the computed median position of the receiver
            %
            % OUTPUT
            %   xyz     geocentric coordinates
            %
            % SYNTAX
            %   xyz = this.getMedianPosXYZ()

            xyz = [];
            for r = 1 : numel(this)
                if isempty(median(this(r).out.getPosXYZ(), 1))
                    xyz = [xyz; nan(1,3)]; %#ok<AGROW>
                else
                    xyz = [xyz; median(this(r).out.getPosXYZ(), 1)]; %#ok<AGROW>
                end
            end
        end

        function [lat, lon, h_ellips, h_ortho] = getMedianPosGeodetic(sta_list)
            % return the computed median position of the receiver
            % MultiRec: works on an array of receivers
            %
            % OUTPUT
            %   lat         latitude  [deg]
            %   lon         longitude [deg]
            %   h_ellips    ellipsoidical heigth [m]
            %   h_ortho     orthometric heigth [m]
            %
            % SYNTAX
            %   [lat, lon, h_ellips, h_ortho] = sta_list.getMedianPosGeodetic();

            lat = nan(numel(sta_list), 1);
            lon = nan(numel(sta_list), 1);
            h_ellips = nan(numel(sta_list), 1);
            h_ortho = nan(numel(sta_list), 1);
            for r = 1 : numel(sta_list)
                if sta_list(1).static
                    [lat(r), lon(r), h_ellips(r), h_ortho(r)] = sta_list(r).out.getMedianPosGeodetic;
                else
                    [lat{r}, lon{r}, h_ellips{r}, h_ortho{r}] = sta_list(r).out.getMedianPosGeodetic;
                end
            end
        end

        function getChalmersString(sta_list)
            % Get the string of the station to be used in http://holt.oso.chalmers.se/loading/
            %
            % SYNTAX
            %   this.getChalmersString(sta_list);

            sta_list(1).log.addMarkedMessage('Chalmers ocean loading computation must be required manually:');
            sta_list(1).log.addMessage(sta_list(1).log.indent('go to http://holt.oso.chalmers.se/loading/ and request a BLQ file'));
            sta_list(1).log.addMessage(sta_list(1).log.indent('using ocean tide model FES2004'));
            % sta_list(1).log.addMessage(sta_list(1).log.indent('select also to compensate the values for the motion'));
            sta_list(1).log.addMessage(sta_list(1).log.indent('Use the following string for the station locations:'));
            sta_list(1).log.addMessage([char(8) '//------------------------------------------------------------------------']);

            for r = 1 : size(sta_list, 2)
                rec = sta_list(~sta_list(:,r).isEmpty, r);
                if ~isempty(rec)
                    xyz = rec.out.getMedianPosXYZ();
                    if isempty(xyz)
                        xyz = rec.work.getMedianPosXYZ();
                    end
                    sta_list(1).log.addMessage([char(8) sprintf('%-24s %16.4f%16.4f%16.4f', rec(1).getMarkerName4Ch, xyz(1), xyz(2),xyz(3))]);
                end
            end

            sta_list(1).log.addMessage([char(8) '//------------------------------------------------------------------------']);
        end

        function [pressure, temperature, humidity, p_time, id_sync] = getPTH_mr(sta_list)
            % Get synced data of TPH
            % MultiRec: works on an array of receivers
            %
            % SYNTAX
            %  [pressure, temperaure, humidiy, p_time, id_sync] = this.getPTH_mr()

            [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(sta_list);

            id_ok = any(~isnan(id_sync),2);
            id_sync = id_sync(id_ok, :);
            p_time = p_time.getEpoch(id_ok);

            n_rec = numel(sta_list);
            pressure = nan(size(id_sync));
            for r = 1 : n_rec
                id_rec = id_sync(:,r);
                id_rec(id_rec > length(sta_list(r).out.pressure)) = nan;
                pressure(~isnan(id_rec), r) = sta_list(r).out.pressure(id_rec(~isnan(id_rec)));
            end

            n_rec = numel(sta_list);
            temperature = nan(size(id_sync));
            for r = 1 : n_rec
                id_rec = id_sync(:,r);
                id_rec(id_rec > length(sta_list(r).out.temperature)) = nan;
                temperature(~isnan(id_rec), r) = sta_list(r).out.temperature(id_rec(~isnan(id_rec)));
            end

            n_rec = numel(sta_list);
            humidity = nan(size(id_sync));
            for r = 1 : n_rec
                id_rec = id_sync(:,r);
                id_rec(id_rec > length(sta_list(r).out.humidity)) = nan;
                humidity(~isnan(id_rec), r) = sta_list(r).out.humidity(id_rec(~isnan(id_rec)));
            end
        end

        function [ztd_res, p_time, ztd_height] = getReducedZtd_mr(sta_list, degree)
            % Reduce the ZTD of all the stations removing the component dependent with the altitude
            % Return synced ZTD
            % MultiRec: works on an array of receivers
            %
            % SYNTAX
            %  [ztd_res, p_time, ztd_height] = sta_list.getReducedZtd_mr()

            med_ztd = median(sta_list.getZtd_mr, 'omitnan')';
            if nargin == 1
                degree = 5;
            end
            [~, ~, ~, h_o] = Coordinates.fromXYZ(sta_list.getMedianPosXYZ()).getGeodetic;

            ztd_height = Core_Utils.interp1LS(h_o, med_ztd, degree);
            [ztd, p_time] = sta_list.getZtd_mr();
            ztd_res = bsxfun(@minus, ztd', ztd_height)';
        end

        function [zwd_res, p_time, zwd_height] = getReducedZwd_mr(sta_list, degree)
            % Reduce the ZWD of all the stations removing the component dependent with the altitude
            % Return synced ZWD
            % MultiRec: works on an array of receivers
            %
            % SYNTAX
            %  [ztd_res, p_time, ztd_height] = sta_list.getReducedZwd_mr()

            med_zwd = median(sta_list.getZwd_mr, 'omitnan')';
            if nargin == 1
                degree = 5;
            end
            [~, ~, ~, h_o] = Coordinates.fromXYZ(sta_list.getMedianPosXYZ()).getGeodetic;

            zwd_height = Core_Utils.interp1LS(h_o, med_zwd, degree);
            [zwd, p_time] = sta_list.getZwd_mr();
            zwd_res = bsxfun(@minus, zwd', zwd_height)';
        end
        
        function [pwv, p_time, id_sync] = getPwv_mr(sta_list)
            % Get synced data of pwv
            % MultiRec: works on an array of receivers
            %
            % SYNTAX
            %  [pwv, p_time, id_sync] = sta_list.getPwv_mr()
            [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(sta_list);

            id_ok = any(~isnan(id_sync),2);
            id_sync = id_sync(id_ok, :);
            p_time = p_time.getEpoch(id_ok);

            n_rec = numel(sta_list);
            pwv = nan(size(id_sync));
            for r = 1 : n_rec
                id_rec = id_sync(:,r);
                id_rec(id_rec > length(sta_list(r).out.pwv)) = nan;
                pwv(~isnan(id_rec), r) = sta_list(r).out.pwv(id_rec(~isnan(id_rec)));
            end
        end

        function [di, p_time, id_sync] = getSlantDispersionIndex_mr(sta_list)
            % Get synced data of dispersion index
            % Dispersion Index is computed as moving mean of var of slant total delay
            % MultiRec: works on an array of receivers
            %
            % SYNTAX
            %  [zwd, p_time, id_sync] = this.getZwd_mr()
            %  [zwd, p_time, id_sync, tge, tgn] = this.getZwd_mr()
            [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(sta_list);

            % Supposing all the station with the same constellation
            di = zeros(size(id_sync, 1), numel(sta_list));
            for r = 1 : numel(sta_list)
                try
                    sztd = sta_list(r).out.getSlantZTD(sta_list(r).slant_filter_win);
                    sztd = bsxfun(@minus, sztd, sta_list(r).out.ztd(id_sync(~isnan(id_sync(:, r)), r)));
                    di_tmp = 1e3 * sqrt(movmean(var(sztd', 'omitnan'), 1800 / sta_list(r).out.time.getRate, 'omitnan'));
                    di(~isnan(id_sync(:, r)), r) = di_tmp(id_sync(~isnan(id_sync(:, r)), r));
                catch
                    % missing station or invalid dataset
                end
            end
        end

        function [ztd, p_time, id_sync, tge, tgn] = getZtd_mr(sta_list)
            % Get synced data of ztd
            % MultiRec: works on an array of receivers
            %
            % SYNTAX
            %  [ztd, p_time, id_sync] = this.getZtd_mr()
            %  [ztd, p_time, id_sync, tge, tgn] = this.getZtd_mr()

            [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(sta_list);

            id_ok = any(~isnan(id_sync),2);
            id_sync = id_sync(id_ok, :);
            p_time = p_time.getEpoch(id_ok);

            n_rec = numel(sta_list);
            ztd = nan(size(id_sync));
            for r = 1 : n_rec
                id_rec = id_sync(:,r);
                id_rec(id_rec > length(sta_list(r).out.ztd)) = nan;
                ztd(~isnan(id_rec), r) = sta_list(r).out.ztd(id_rec(~isnan(id_rec)));
            end

            if nargout == 5
                tge = nan(size(id_sync));
                tgn = nan(size(id_sync));
                for r = 1 : n_rec
                    id_rec = id_sync(:,r);
                    id_rec(id_rec > length(sta_list(r).out.ztd)) = nan;
                    tge(~isnan(id_rec), r) = sta_list(r).out.tge(id_rec(~isnan(id_rec)));
                    tgn(~isnan(id_rec), r) = sta_list(r).out.tgn(id_rec(~isnan(id_rec)));
                end
            end
        end

        function [zwd, p_time, id_sync, tge, tgn] = getZwd_mr(sta_list)
            % Get synced data of zwd
            % MultiRec: works on an array of receivers
            %
            % SYNTAX
            %  [zwd, p_time, id_sync] = this.getZwd_mr()
            %  [zwd, p_time, id_sync, tge, tgn] = this.getZwd_mr()

            [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(sta_list);

            id_ok = any(~isnan(id_sync),2);
            id_sync = id_sync(id_ok, :);
            p_time = p_time.getEpoch(id_ok);

            n_rec = numel(sta_list);
            zwd = nan(size(id_sync));
            for r = 1 : n_rec
                id_rec = id_sync(:,r);
                id_rec(id_rec > length(sta_list(r).out.zwd)) = nan;
                zwd(~isnan(id_rec), r) = sta_list(r).out.zwd(id_rec(~isnan(id_rec)));
            end

            if nargout == 5
                tge = nan(size(id_sync));
                tgn = nan(size(id_sync));
                for r = 1 : n_rec
                    id_rec = id_sync(:,r);
                    id_rec(id_rec > length(sta_list(r).out.zwd)) = nan;
                    tge(~isnan(id_rec), r) = sta_list(r).out.tge(id_rec(~isnan(id_rec)));
                    tgn(~isnan(id_rec), r) = sta_list(r).out.tgn(id_rec(~isnan(id_rec)));
                end
            end
        end

        function [tropo, time] = getTropoPar(sta_list, par_name)
            % Get a tropo parameter among 'ztd', 'zwd', 'pwv', 'zhd'
            % Generic function multi parameter getter
            %
            % SYNTAX
            %  [tropo, p_time] = sta_list.getAprZhd()

            tropo = {};
            time = {};
            for r = 1 : numel(sta_list)
                time{r} = sta_list(r).out.getTime();
                switch lower(par_name)
                    case 'ztd'
                        [tropo{r}] = sta_list(r).out.getZtd();
                    case 'zwd'
                        [tropo{r}] = sta_list(r).out.getZwd();
                        if isempty(tropo{r}) || all(isnan(zero2nan(tropo{r})))
                            [tropo{r}] = sta_list(r).out.getAprZwd();
                        end
                    case 'gn'
                        [tropo{r}] = sta_list(r).out.getGradient();
                    case 'ge'
                        [~,tropo{r}] = sta_list(r).out.getGradient();
                    case 'pwv'
                        [tropo{r}] = sta_list(r).out.getPwv();
                    case 'zhd'
                        [tropo{r}] = sta_list(r).out.getAprZhd();
                    case 'nsat'
                        [tropo{r}] = sta_list(r).out.getNSat();
                end
            end

            if numel(tropo) == 1
                tropo = tropo{1};
                time = time{1};
            end
        end

        function [tropo, time] = getZtd(sta_list)
            % Get ZTD
            %
            % SYNTAX
            %  [tropo, p_time] = sta_list.getZtd()
            [tropo, time] = sta_list.getTropoPar('ztd');
        end

        function [n_sat, time] = getNumSat(sta_list)
            % Get the number of satellite in view per epoch
            %
            % SYNTAX
            %  [tropo, p_time] = sta_list.getNumSat()
            [n_sat, time] = sta_list.getTropoPar('nsat');
        end

        function [tropo, time] = getZwd(sta_list)
            % Get ZWD
            %
            % SYNTAX
            %  [tropo, p_time] = sta_list.getZwd()
            [tropo, time] = sta_list.getTropoPar('zwd');
        end

        function [tropo, time] = getPwv(sta_list)
            % Get PWV
            %
            % SYNTAX
            %  [tropo, p_time] = sta_list.getPwv()
            [tropo, time] = sta_list.getTropoPar('pwv');
        end

        function [tropo, time] = getAprZhd(sta_list)
            % Get a-priori ZHD
            %
            % SYNTAX
            %  [tropo, p_time] = sta_list.getAprZhd()
            [tropo, time] = sta_list.getTropoPar('zhd');
        end

        function [m_diff, s_diff] = getRadiosondeValidation(sta_list, rds_list, flag_show)
            % Compute a comparison with radiosondes from weather.uwyo.edu
            % given region list, and station id (as cell arrays)
            %
            % INPUT
            %   sta_list        list of gnss receivers
            %   rds_list        cell array of string containing the radiosonde ID as used at "http://weather.uwyo.edu/upperair/sounding.html"
            %
            % OUTPUT
            %   m_diff          mean of the ZTD differences
            %   s_diff          std of the ZTD differences
            %
            % SYNTAX
            %  [m_diff, s_diff] = sta_list.getRadiosondeValidation(station_list);
            %
            % EXAMPLE
            %  % testing geonet full network
            %  [m_diff, s_diff] = sta_list.getRadiosondeValidation(Radiosonde.JAPAN_STATION);
            %
            % SEE ALSE
            %   Radiosonde
            
            if nargin < 3
                 flag_show = false;
            end
            
            Logger.getInstance.addMarkedMessage('Retrieving data, please wait...');
            % Get time limits
            p_time = sta_list.getSyncTimeExpanded(sta_list);
            start_time = GPS_Time(floor(p_time.first.getMatlabTime * 2)/2);
            stop_time = GPS_Time(ceil(p_time.last.getMatlabTime * 2)/2);

            % Download radiosondes
            rds = Radiosonde.fromList(rds_list, start_time, stop_time);
            
            Logger.getInstance.addMarkedMessage('Get GNSS interpolated ZTD @ radiosonde locations');
            [ztd, ztd_height_correction, time] = sta_list.getTropoInterp('ZTD', rds.getLat(), rds.getLon(), rds.getElevation());
            
            
            % Get closer GNSS stations
            [id_rec, d3d, dup] = sta_list.getCloserRec(rds.getLat(), rds.getLon(), rds.getElevation());
            gnss_list = sta_list(id_rec);

            % Compute values
            fprintf('---------------------------------------------------------------------\n');
            [m_diff, s_diff] = deal(nan(numel(rds), 1));
            for s = 1 : numel(rds)
                % radiosondes
                [ztd_rds, time_rds] = rds(s).getZtd();
                
                id_min = zeros(time_rds.length, 1);
                ztd_diff = nan(time_rds.length, 1);
                for e = 1 : time_rds.length
                    [t_min, id_min(e)] = min(abs(time - time_rds.getEpoch(e)));
                    ztd_diff(e) = ztd_rds(e) - (ztd(id_min(e),s) + ztd_height_correction(s));
                end
                
                m_diff(s) = mean(ztd_diff, 1, 'omitnan');
                s_diff(s) = std(ztd_diff, 1, 'omitnan');
                fprintf('%2d) G  %6.2f cm    %6.2f cm     Radiosonde "%s"\n', s, m_diff(s), s_diff(s), rds(s).getName());
            end
            fprintf('---------------------------------------------------------------------\n');

            if flag_show
                % Plot comparisons
                for s = 1 : numel(rds)
                    f = figure; dockAllFigures(f);
                    f.Name = sprintf('%03d: Rds %d', f.Number, s); f.NumberTitle = 'off';
                    
                    % interpolated ZTD
                    plot(time.getMatlabTime, ztd(:,s) + ztd_height_correction(s), '-', 'LineWidth', 2);
                    hold on;
                    
                    % closer ZTD
                    [s_ztd, s_time] = sta_list(id_rec(s)).getZtd_mr();
                    plot(s_time.getMatlabTime, s_ztd * 1e2, '-', 'LineWidth', 2);
                    
                    % radiosondes
                    [ztd_rds, time_rds] = rds(s).getZtd();
                    plot(time_rds.getMatlabTime, ztd_rds, '.k', 'MarkerSize', 40);
                    dockAllFigures();
                    legend({'ZTD GPS from interpolation', sprintf('ZTD GPS of %s', sta_list(id_rec(s)).getMarkerName4Ch), ...
                        sprintf('Radiosonde @ %s', rds(s).getName())}, 'location', 'northwest');
                    title(sprintf('ZTD comparison @ %d Km (%.1f m up)\\fontsize{5} \n', round(d3d(s) / 1e3), dup(s)));
                    setTimeTicks; grid minor;
                    drawnow;
                    ax = gca; ax.FontSize = 16;
                end
                %fh.WindowStyle = 'normal'; fh.Units = 'pixels'; fh.Position = [1, 1, 1000, 600];
                %Core_Utils.exportCurFig(fullfile(Core.getState.getHomeDir, 'Images', sprintf('Radiosonde_comparison_%s.png', rds(s).getName)));
            end
            
            % Plot map of all the radiosondes tests ----------------------------------------------
            % Retrieve DTM model
            
            if flag_show
                Logger.getInstance.addMarkedMessage('Preparing map, please wait...');
                % set map limits
                nwse = [48, 123, 22, 148];
                clon = nwse([2 4]) + [-0.02 0.02];
                clat = nwse([3 1]) + [-0.02 0.02];
                
                fh = figure; fh.Color = [1 1 1]; maximizeFig(fh);
                %m_proj('equidistant','lon',clon,'lat',clat);   % Projection
                m_proj('utm', 'lon',clon,'lat',clat);   % Projection
                axes
                cmap = flipud(gray(1000)); colormap(cmap(150: end, :));
                %colormap(Cmap.adaptiveTerrain(minMax(dtm(:))));
                drawnow;
                
                % retrieve external DTM
                try
                    [dtm, lat, lon] = Core.getRefDTM(nwse, 'ortho', 'high');
                    dtm = flipud(dtm);
                    dtm(dtm < -1) = nan; %1/3 * max(dtm(:));
                    [shaded_dtm, x, y] = m_shadedrelief(lon, lat, dtm, 'nan', [0.98, 0.98, 1]);
                    h_dtm = m_pcolor(lon, lat, dtm);
                    h_dtm.CData = shaded_dtm;
                catch
                    % use ETOPO1 instead
                    m_etopo2('shadedrelief','gradient', 3);
                end
                
                % read shapefile
                shape = 'none';
                if (~strcmp(shape,'none'))
                    if (~strcmp(shape,'coast')) && (~strcmp(shape,'fill'))
                        if (strcmp(shape,'10m'))
                            M = m_shaperead('countries_10m');
                        elseif (strcmp(shape,'30m'))
                            M = m_shaperead('countries_30m');
                        else
                            M = m_shaperead('countries_50m');
                        end
                        [x_min, y_min] = m_ll2xy(min(lon_lim), min(lat_lim));
                        [x_max, y_max] = m_ll2xy(max(lon_lim), max(lat_lim));
                        for k = 1 : length(M.ncst)
                            lam_c = M.ncst{k}(:,1);
                            ids = lam_c <  min(lon);
                            lam_c(ids) = lam_c(ids) + 360;
                            phi_c = M.ncst{k}(:,2);
                            [x, y] = m_ll2xy(lam_c, phi_c);
                            if sum(~isnan(x))>1
                                x(find(abs(diff(x)) >= abs(x_max - x_min) * 0.90) + 1) = nan; % Remove lines that occupy more than th 90% of the plot
                                line(x,y,'color', [0.3 0.3 0.3]);
                            end
                        end
                    else
                        if (strcmp(shape,'coast'))
                            m_coast('line','color', lineCol);
                        else
                            m_coast('patch',lineCol);
                        end
                    end
                end
                
                hold on;
                
                m_grid('box','fancy','tickdir','in', 'fontsize', 16);
                % m_ruler([.5 .90], .05, 'tickdir','out','ticklen',[.007 .007], 'fontsize',14);
                % m_ruler(1.1, [.05 .40], 'tickdir','out','ticklen',[.007 .007], 'fontsize',14);
                
                % Radiometers points
                data_mean = m_diff;
                data_std = s_diff;
                data_lat = rds.getLat();
                data_lon = rds.getLon();
                
                [x, y] = m_ll2xy(data_lon, data_lat);
                
                plot(x(:), y(:),'.k', 'MarkerSize', 5);
                % Label BG (in background w.r.t. the point)
                for r = 1 : numel(gnss_list)
                    %name = rds(r).getName;
                    name = sprintf('%.1f, %.1f', data_mean(r), data_std(r));
                    text(x(r), y(r), char(32 * ones(1, 2 + 2 * length(name), 'uint8')), ...
                        'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0], ...
                        'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                        'Margin', 2, 'LineWidth', 2, ...
                        'HorizontalAlignment','left');
                end
                
                for r = 1 : numel(rds)
                    %name = rds(r).getName;
                    name = sprintf('%.1f, %.1f', data_mean(r), data_std(r));
                    t = text(x(r), y(r), ['     ' name], ...
                        'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0], ...
                        ...%'FontWeight', 'bold', 'FontSize', 10, 'Color', [0 0 0], ...
                        ...%'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                        'Margin', 2, 'LineWidth', 2, ...
                        'HorizontalAlignment','left');
                end
                
                n_col = round(max(abs(minMax(data_mean))*10));
                %col_data = Cmap.getColor(round(data_mean * 10) + n_col, 2 * n_col, 'RdBu');
                col_data = Cmap.getColor(round(abs(data_mean) * 10) + 1, n_col + 1, 'linspaced');
                for r = 1 : numel(gnss_list)
                    plot(x(r), y(r), '.', 'MarkerSize', 100, 'Color', col_data(r,:));
                end
                caxis(n_col * [0 1] ./ 10); colormap(Cmap.get('linspaced', n_col));
                plot(x(:), y(:), 'ko', 'MarkerSize', 28, 'LineWidth', 2);
                
                ax = m_contfbar(.97,[.55 .95],[0 n_col/10], 0:0.1:(n_col/10),'edgecolor','none','endpiece','no', 'fontsize', 16);
                xlabel(ax,'cm','color','k');
                title(sprintf('Map of mean and std of radiosonde validation\\fontsize{5} \n', round(d3d(s) / 1e3), dup(s)), 'FontSize', 16);
                
                Logger.getInstance.addStatusOk('The map is ready ^_^');
            end
        end
        
        function [tropo_grid, x_grid, y_grid, time, tropo_height_correction, tropo_clim] = getTropoMap(sta_list, par_name, rate, flag_show)
            % Get interpolated map of tropospheric parameter
            % Resolution is determined by the dtm in use (2 * 0.029 degrees)
            % The map is computer only on ground (> 10m) + 1 degree of margin
            %
            % INPUT
            %   par_name    type of tropospheric parameter:
            %                - ztd
            %                - zwd
            %                - pwv
            %   rate        rate in seconds, nearest to closest observation 
            %               it should be a subsample of the data rate (e.g. 300 with 30s data)
            %   flag_show   if true show debug images
            %
            % SYNTAX
            %   [tropo_grid, x_grid, y_grid, time, tropo_height_correction] = sta_list.getTropoMap(par_name, rate)
            
            % Defining interpolation
            method = 'natural';
            dtm_size = 600; % keep dtm points smaller than dtm_size x dtm_size
            fun = @(dist) 0.2 * exp(-(dist)*1e1) + 0*exp(-(dist*5e1).^2);
            %fun = @(dist) 1./(dist+1e-5);

            if nargin < 4
                flag_show = false;
            end
            
            sta_list = sta_list(~sta_list.isEmptyOut_mr);
            switch lower(par_name)
                case 'ztd'
                    [tropo, s_time] = sta_list.getZtd_mr();
                case 'zwd'
                    [tropo, s_time] = sta_list.getZwd_mr();
                case 'gn'
                    [~, s_time, ~, ~, tropo] = sta_list.getZwd_mr();
                case 'ge'
                    [~, s_time, ~, tropo, ~]  = sta_list.getZwd_mr();
                case 'dir'
                    [~, s_time, ~, ge, gn]  = sta_list.getZwd_mr();
                    tropo = atan2d(gn, ge) - 90;
                case 'pwv'
                    [tropo, s_time] = sta_list.getPwv_mr();
                case 'zhd'
                case 'nsat'
            end
            tropo = tropo * 1e2;
            
            if (nargin < 3) || isempty(rate)
                rate = 300; % 5 min
            end
            ss_rate = round(rate / s_time.getRate);
            time = s_time.getEpoch(1 : ss_rate : s_time.length());

            med_tropo = mean(tropo, 1, 'omitnan')';

            degree = 4;
            coo = Coordinates.fromXYZ(sta_list.getMedianPosXYZ);
            [lat, lon, up, h_o] = coo.getGeodetic;
                        
            xyu = [lon / pi * 180, lat / pi * 180, up];
            
            % Remove missing stations
            id_ok = ~isnan(tropo'); % logical matrix of valid tropo
            
            % Generate interpolation grid
            x_span = max(xyu(:,1)) - min(xyu(:,1));
            y_span = max(xyu(:,2)) - min(xyu(:,2));
            border = 5;
            step = 0.05; % Grid step in degrees (only for defining limits)
            x_lim = [((floor(min(xyu(:,1)) / step) - border) * step), ((ceil(max(xyu(:,1)) / step) + border) * step)];
            y_lim = [((floor(min(xyu(:,2)) / step) - border) * step), ((ceil(max(xyu(:,2)) / step) + border) * step)];
            
            % Retrieve DTM model
            nwse = [max(y_lim), min(x_lim), min(y_lim), max(x_lim)];
            [dtm, lat, lon] = Core.getRefDTM(nwse, 'ortho', 'low');
            
            % I don't really need full resolution (maybe in a future)
            k = ceil(sqrt(numel(dtm)) / dtm_size);
            %k = 1;
            dtm = dtm(1:k:end, 1:k:end);
            lat = lat(1:k:end);
            lon = lon(1:k:end);
            
            % Correct data for height
            tropo_height = Core_Utils.interp1LS(h_o, med_tropo, degree);
            tropo_res = bsxfun(@minus, tropo', tropo_height)';            

            % Redifine the grid of the map to produce on the basis of the available DTM
            x_grid = lon';
            y_grid = flipud(lat)';
            x_step = median(diff(x_grid));
            y_step = median(diff(y_grid));
            [x_mg, y_mg] = meshgrid(x_grid, y_grid);

            % Generate computation mask (to limit points to interpolate)
            x_id = round((xyu(:,1) - x_grid(1)) / x_step) + 1;
            y_id = round((xyu(:,2) - y_grid(1)) / y_step) + 1;
            mask = zeros(size(y_grid, 2), size(x_grid, 2));
            mask((x_id - 1) * size(y_grid, 2) + y_id) = 1;
            % Refine mask keeping only points above sea level close to the station to process
            [xg, yg] = meshgrid(x_id, y_id); 
            d = max(25, round(perc(noNaN(zero2nan(lower(sqrt((xg - xg').^2 + (yg - yg').^2)))), 0.35))); % 20% of min distance is uused to enlarge the area of interpolation
            mask = (circConv2(mask, d) > 0) & (dtm >= -10);
            conv_mask = [0 0 1 1 1 0 0; ...
                         0 1 1 1 1 1 0; ...
                         1 1 1 1 1 1 1; ...
                         1 1 1 1 1 1 1; ...
                         1 1 1 1 1 1 1; ...
                         0 1 1 1 1 1 0; ...
                         0 0 1 1 1 0 0];
            conv_mask2 = [0 0 0 1 1 1 1 1 0 0 0; ...
                         0 0 1 1 1 1 1 1 1 0 0; ...
                         0 1 1 1 1 1 1 1 1 1 0; ...
                         1 1 1 1 1 1 1 1 1 1 1; ...
                         1 1 1 1 1 1 1 1 1 1 1; ...
                         1 1 1 1 1 1 1 1 1 1 1; ...
                         1 1 1 1 1 1 1 1 1 1 1; ...
                         1 1 1 1 1 1 1 1 1 1 1; ...
                         0 1 1 1 1 1 1 1 1 1 0; ...
                         0 0 1 1 1 1 1 1 1 0 0; ...
                         0 0 0 1 1 1 1 1 0 0 0;];
            mask = (circConv2(single(mask), conv_mask) > 0); % enlarge a bit the mask

            % Get DTM tropospheric correction
            dtm(dtm < 0) = 0; % do not consider bathimetry
            if nargout < 5 && nargin < 3
                h_correction = Core_Utils.interp1LS([h_o; 5000 * ones(100,1)], [med_tropo;  zeros(100,1)], degree, 0);
            else
                h_list = 0 : max(ceil(dtm(:)));
                h_correction = Core_Utils.interp1LS([h_o; 5000 * ones(100,1)], [med_tropo;  zeros(100,1)], degree, h_list);
            
                % Compute map of tropo corrections for height displacements
                tropo_height_correction = nan(size(dtm));
                tropo_height_correction(:) = (h_correction(round(max(0, dtm(:)) + 1)) - h_correction(1));
            end
            
            % List of valide epochs (opening an aproximate window around the points)
            x_list = x_mg(mask);
            y_list = y_mg(mask);
            
            epoch = 1 : s_time.length();
            epoch_list = 1 : ss_rate : numel(epoch);
            
            tropo_grid = nan(size(mask,1), size(mask,2), numel(epoch_list), 'single'); 
            
            if flag_show
                % IMAGE DEBUG: 
                fig_handle = figure; maximizeFig(fig_handle);
            end

            w_bar = Core.getWaitBar();
            w_bar.createNewBar('Generating maps of troposphere');
            w_bar.setBarLen(numel(epoch_list));
            
            tropo_clim = tropo_res + h_correction(1);
            tropo_clim = [perc(tropo_clim(:),0.005) perc(tropo_clim(:),0.995)];
            tropo_clim(2,:) = [perc(tropo(:),0.005) perc(tropo(:),0.995)];

            if flag_show
                subplot(1,2,1);
                imh = imagesc(x_grid, y_grid, tropo_height_correction);
                if FTP_Downloader.checkNet()
                    plot_google_map('alpha', 0.65, 'MapType', 'satellite');
                end
                xlabel('Longitude [deg]');
                ylabel('Latitude [deg]');
                caxis(tropo_clim(1,:));
                colorbar;
                th = title(sprintf([par_name ' [cm] map @%s at sea level'], time.getEpoch(1).toString('yyyy-mm-dd HH:MM:SS')), 'FontSize', 22);
                    
                ax2 = subplot(1,2,2);
                imh2 = imagesc(x_grid, y_grid, tropo_height_correction);
                if FTP_Downloader.checkNet()
                    plot_google_map('alpha', 0.65, 'MapType', 'satellite');
                    %plot_google_map('alpha', 0.65, 'MapType', 'roadmap');
                end
                xlabel('Longitude [deg]');
                ylabel('Latitude [deg]');
                caxis(tropo_clim(2,:));
                cmap = Cmap.get('c51', 501);
                colormap(flipud(cmap(2:end,:)));
                colorbar;
                th2 = title(ax2, 'at ground level', 'FontSize', 22);                
            end

            for i = 1 : numel(epoch_list)
                e = epoch_list(i);
                if sum(id_ok(:, epoch(e))) > 2
                    th.String = sprintf([par_name ' [cm] map %s at sea level'], time.getEpoch(i).toString('yyyy-mm-dd HH:MM:SS'));
                    tmp = nan(size(mask));
                    if strmatch(method, 'fun')
                        tmp(mask) = funInterp2(x_list, y_list, xyu(id_ok(:, epoch(e)),1), xyu(id_ok(:, epoch(e)),2), tropo_res(epoch(e), id_ok(:, epoch(e)))', fun);
                    else
                        finterp = scatteredInterpolant(xyu(id_ok(:, epoch(e)),1),xyu(id_ok(:, epoch(e)),2), tropo_res(epoch(e), id_ok(:, epoch(e)))', method, 'none');
                        tmp(mask) = finterp(x_list, y_list);
                    end
                    tropo_grid(:,:,i) = single(tmp) + h_correction(1);
                    if flag_show                        
                        imh.CData = tropo_grid(:,:,i);
                        imh.AlphaData = ~isnan(tropo_grid(:,:,i));
                        imh2.CData = tropo_grid(:,:,i) + tropo_height_correction;
                        imh2.AlphaData = ~isnan(tropo_grid(:,:,i));
                        drawnow;
                    end
                else
                    if i > 1
                        tropo_grid(:,:,i) = tropo_grid(:,:,i) - 1;
                    end
                end
                w_bar.goTime(i);
            end
            w_bar.close();
        end
        
        function [tropo_out, tropo_height_correction, time] = getTropoInterp(sta_list, par_name, dlat_out, dlon_out, h_out)
            % Get interpolated map of tropospheric parameter
            % Resolution is determined by the dtm in use (2 * 0.029 degrees)
            % The map is computer only on ground (> 10m) + 1 degree of margin
            %
            % INPUT
            %   par_name    type of tropospheric parameter:
            %                - ztd
            %                - zwd
            %                - pwv
            %   rate        rate in seconds, nearest to closest observation 
            %               it should be a subsample of the data rate (e.g. 300 with 30s data)
            %   flag_show   if true show debug images
            %
            % SYNTAX
            %   [tropo_grid, x_grid, y_grid, time, tropo_height_correction] = sta_list.getTropoMap(par_name, rate)
            
            % Defining interpolation
            method = 'natural';
            fun = @(dist) 0.2 * exp(-(dist)*1e1) + 0*exp(-(dist*5e1).^2);
            %fun = @(dist) 1./(dist+1e-5);
            
            sta_list = sta_list(~sta_list.isEmptyOut_mr);
            switch lower(par_name)
                case 'ztd'
                    [tropo, s_time] = sta_list.getZtd_mr();
                case 'zwd'
                    [tropo, s_time] = sta_list.getZwd_mr();
                case 'gn'
                    [~, s_time, ~, ~, tropo] = sta_list.getZwd_mr();
                case 'ge'
                    [~, s_time, ~, tropo, ~]  = sta_list.getZwd_mr();
                case 'dir'
                    [~, s_time, ~, ge, gn]  = sta_list.getZwd_mr();
                    tropo = atan2d(gn, ge) - 90;
                case 'pwv'
                    [tropo, s_time] = sta_list.getPwv_mr();
                case 'zhd'
                case 'nsat'
            end
            tropo = tropo * 1e2;
            
            time = s_time; % s_time.getEpoch(1 : s_time.length());
            med_tropo = mean(tropo, 1, 'omitnan')';

            degree = 4;
            coo = Coordinates.fromXYZ(sta_list.getMedianPosXYZ);
            [lat, lon, up, h_o] = coo.getGeodetic;
            
            xyu = [dlon_out, dlat_out, h_out];
            
            % Remove missing stations
            id_ok = ~isnan(tropo'); % logical matrix of valid tropo
                                                
            % Correct data for height
            tropo_height = Core_Utils.interp1LS(h_o, med_tropo, degree);
            tropo_res = bsxfun(@minus, tropo', tropo_height)';            

            h_correction = Core_Utils.interp1LS([h_o; 5000 * ones(100,1)], [med_tropo;  zeros(100,1)], degree, [0; h_out(:)]);
            
            % Compute map of tropo corrections for height displacements
            tropo_height_correction = h_correction(2:end) - h_correction(1);
                        
            % List of valide epochs (opening an aproximate window around the points)
            x_list = lon ./ pi * 180;
            y_list = lat ./ pi * 180;
            
            epoch = 1 : s_time.length();
            epoch_list = 1 : numel(epoch);
            
            tropo_out = nan(size(dlat_out,1), numel(epoch_list), 'single'); 
                     
            w_bar = Core.getWaitBar();
            w_bar.createNewBar('Generating maps of troposphere');
            w_bar.setBarLen(numel(epoch_list));
            
            for i = 1 : numel(epoch_list)
                e = epoch_list(i);
                if sum(id_ok(:, epoch(e))) > 2
                    if strmatch(method, 'fun')
                        tmp = funInterp2(dlon_out, dlat_out, x_list(id_ok(:, epoch(e))), y_list(id_ok(:, epoch(e))), tropo_res(epoch(e), id_ok(:, epoch(e)))', fun);
                    else
                        finterp = scatteredInterpolant(x_list(id_ok(:, epoch(e))), y_list(id_ok(:, epoch(e))), tropo_res(epoch(e), id_ok(:, epoch(e)))', method, 'none');
                        tmp = finterp(dlon_out, dlat_out);
                    end
                    tropo_out(:,i) = single(tmp) + h_correction(1);
                else
                    if i > 1
                        tropo_out(:,i) = tropo_out(:,i) - 1;
                    end
                end
                w_bar.goTime(i);
            end
            w_bar.close();
            tropo_out = tropo_out';
        end

        function [id_rec, dist_3d, dist_up] = getCloserRec(sta_list, lat, lon, h_o)
            % Get the id and 3D distance of the closest station w.r.t. a given point
            %
            % INPUT 
            %   lat, lon    [degree]
            %   h_o         [m] orthometric height
            %
            % OUTPUT
            %   id_rec      id of the closest GNSS station
            %   dist_3d     minimum distance 3D [m] w.r.t. the requested coordinates
            %   dist_up     minimum distance up [m] w.r.t. the requested coordinates
            %
            % SYNTAX
            %   [id_rec, dist_3d, dist_up] = sta_list.getCloserRec(lat, lon, h_o)
            
            if nargin == 3
                h_o = 0;
            end
            
            sta_xyz = sta_list.getMedianPosXYZ;
            out_coo = Coordinates.fromGeodetic(lat / 180 * pi, lon / 180 * pi, [], h_o);
            out_xyz = out_coo.getXYZ;
            
            n_out = size(out_xyz, 1);
            n_sta = size(sta_xyz, 1);
            
            % check all the distances
            d2 = (repmat(sta_xyz(:,1), 1, n_out) - repmat(out_xyz(:,1)', n_sta, 1)) .^2 + ...
                (repmat(sta_xyz(:,2), 1, n_out) - repmat(out_xyz(:,2)', n_sta, 1)) .^2 + ...
                (repmat(sta_xyz(:,3), 1, n_out) - repmat(out_xyz(:,3)', n_sta, 1)) .^2;
            
            % Keep the closest station
            [d2_min, id_rec] = min(d2);
            dist_3d = sqrt(d2_min);
            [~, ~, ~, h_ortho] = sta_list(id_rec).getMedianPosGeodetic();
            dist_up = h_ortho - h_o;
        end
        
        function rec_works = getWork(sta_list, id)
            % Return the working receiver for a GNSS station array
            %
            % SYNTAX
            %  rec_works = sta_list.getWork(<id>)
            if nargin < 2
                rec_works = [sta_list.work];
            else
                id(id > numel(sta_list)) = [];
                rec_works = [sta_list(id).work];
            end
        end
    end

    % ==================================================================================================================================================
    %% SETTER
    % ==================================================================================================================================================
    methods (Access = public)
        function setSlantFilterSize(this, win_size)
            % Setter multi_receiver to change filtering windows size for slant export
            %
            % SYNTAX
            %   this.setSlantFilterSize(win_size)
            for r = 1 : numel(this)
                this(r).slant_filter_win = win_size;
            end
        end
    end

    % ==================================================================================================================================================
    %% TESTER
    % ==================================================================================================================================================
    methods (Access = public)
        function id_ko = checkZtd_mr(sta_list, flag_verbose)
            % Check ZTD for possible outliers (works on the mr ZTD getter)
            %
            % SYNTAX
            %   id_ko = sta_list.checkZtd_mr(flag_verbose)
            if nargin < 2
                flag_verbose = true;
            end

            ztd = sta_list.getZtd_mr();
            med_ztd = median(ztd * 1e2, 'omitnan')';
            [lat, lon, h_e, h_o] = sta_list.getMedianPosGeodetic();

            log = Logger.getInstance();

            degree = 2;
            h_component = Core_Utils.interp1LS(h_o, med_ztd, degree, h_o);
            ztd_diff = abs(med_ztd - h_component);
            id_ko = find(ztd_diff > 8);

            if not(isempty(id_ko)) && flag_verbose
                log.addMessage('Strange stations detected');
                for s = 1 : numel(id_ko)
                    log.addMessage(sprintf(' - %s out for: %.2f cm wrt global behaviour', sta_list(id_ko(s)).getMarkerName, ztd_diff(id_ko(s))));
                end
            end
        end
    end

    % ==================================================================================================================================================
    %% STATIC FUNCTIONS used as utilities
    % ==================================================================================================================================================
    methods (Static, Access = public)
        function [p_time, id_sync] = getSyncTimeExpanded(rec, p_rate, use_pos_time)
            % Get the common time among all the receivers
            %
            % SYNTAX
            %   [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(rec, <p_rate>, <use_pos_time>);
            %
            % EXAMPLE:
            %   [p_time, id_sync] = GNSS_Station.getSyncTimeExpanded(rec, 30);

            if nargin < 3 || isempty(use_pos_time)
                use_pos_time = false;
            end

            if sum(~rec.isEmpty_mr) == 0
                % no valid receiver
                p_time = GPS_Time;
                id_sync = [];
            else
                if nargin < 2 || isempty(p_rate)
                    p_rate = 1e-6;

                    for r = 1 : numel(rec)
                        if (rec(r).out.time.length) > 2
                            if use_pos_time
                                p_rate = lcm(round(p_rate * 1e6), round(rec(r).out.time_pos.getRate * 1e6)) * 1e-6; % enable this line to sync rates
                            else
                                p_rate = lcm(round(p_rate * 1e6), round(rec(r).out.time.getRate * 1e6)) * 1e-6; % enable this line to sync rates
                            end
                        end
                    end
                end

                % prepare reference time
                % processing time will start with the receiver with the last first epoch
                %          and it will stop  with the receiver with the first last epoch

                out = [rec.out];
                first_id_ok = find(~out.isEmpty_mr, 1, 'first');
                if ~isempty(first_id_ok)
                    if use_pos_time
                        p_time_zero = round(rec(first_id_ok).out.time_pos.first.getMatlabTime() * 24)/24; % get the reference time for positions
                    else
                        p_time_zero = round(rec(first_id_ok).out.time.first.getMatlabTime() * 24)/24; % get the reference time
                    end
                end

                % Get all the common epochs
                t = [];
                for r = 1 : numel(rec)
                    if use_pos_time
                        rec_rate = min(86400, iif(rec(r).out.time_pos.length == 1, 86400, rec(r).out.time_pos.getRate));
                        t = [t; round(rec(r).out.time_pos.getRefTime(p_time_zero) / rec_rate) * rec_rate];
                    else
                        rec_rate = min(1, rec(r).out.time.getRate);
                        t = [t; round(rec(r).out.time.getRefTime(p_time_zero) / rec_rate) * rec_rate];
                    end
                    % p_rate = lcm(round(p_rate * 1e6), round(rec(r).out.time.getRate * 1e6)) * 1e-6; % enable this line to sync rates
                end
                t = unique(t);

                % If p_rate is specified use it
                if nargin > 1
                    t = intersect(t, (t(1) : p_rate : t(end) + p_rate)');
                end

                % Create reference time
                p_time = GPS_Time(p_time_zero, t);
                id_sync = nan(p_time.length(), numel(rec));

                % Get intersected times
                for r = 1 : numel(rec)
                    if use_pos_time
                        rec_rate = iif(rec(r).out.time_pos.length == 1, 86400, rec(r).out.time_pos.getRate);
                        [~, id1, id2] = intersect(t, round(rec(r).out.time_pos.getRefTime(p_time_zero) / rec_rate) * rec_rate);
                    else
                        rec_rate = min(1, rec(r).out.time.getRate);
                        [~, id1, id2] = intersect(t, round(rec(r).out.time.getRefTime(p_time_zero) / rec_rate) * rec_rate);
                    end

                    id_sync(id1, r) = id2;
                end
            end
        end

        function [p_time, id_sync] = getSyncTimeTR(sta_list, obs_type, p_rate)
            % Get the common (shortest) time among all the used receivers and the target(s)
            % For each target (obs_type == 0) produce a different cella arrya with the sync of the other receiver
            % e.g.  Reference receivers @ 1Hz, trg1 @1s trg2 @30s
            %       OUTPUT 1 sync @1Hz + 1 sync@30s
            %
            % SYNTAX
            %   [p_time, id_sync] = Receiver.getSyncTimeTR(rec, obs_type, <p_rate>);
            %
            % SEE ALSO:
            %   this.getSyncTimeExpanded
            %
            if nargin < 3
                p_rate = 1e-6;
            end
            if nargin < 2
                % choose the longest as reference
                len = zeros(1, numel(sta_list));
                for r = 1 : numel(sta_list)
                    len(r) = sta_list(r).out.length;
                end
                obs_type = ones(1, numel(sta_list));
                obs_type(find(len == max(len), 1, 'first')) = 0;
            end

            % Do the target(s) as last
            [~, id] = sort(obs_type, 'descend');

            % prepare reference time
            % processing time will start with the receiver with the last first epoch
            %          and it will stop  with the receiver with the first last epoch

            first_id_ok = find(~sta_list.isEmptyOut_mr, 1, 'first');
            p_time_zero = round(sta_list(first_id_ok).out.time.first.getMatlabTime() * 24)/24; % get the reference time
            p_time_start = sta_list(first_id_ok).out.time.first.getRefTime(p_time_zero);
            p_time_stop = sta_list(first_id_ok).out.time.last.getRefTime(p_time_zero);
            p_rate = lcm(round(p_rate * 1e6), round(sta_list(first_id_ok).out.time.getRate * 1e6)) * 1e-6;

            p_time = GPS_Time(); % empty initialization

            i = 0;
            for r = id
                ref_t{r} = sta_list(r).out.time.getRefTime(p_time_zero);
                if obs_type(r) > 0 % if it's not a target
                    if ~sta_list(r).out.isEmpty
                        p_time_start = max(p_time_start,  round(sta_list(r).out.time.first.getRefTime(p_time_zero) * sta_list(r).out.time.getRate) / sta_list(r).out.time.getRate);
                        p_time_stop = min(p_time_stop,  round(sta_list(r).out.time.last.getRefTime(p_time_zero) * sta_list(r).out.time.getRate) / sta_list(r).out.time.getRate);
                        p_rate = lcm(round(p_rate * 1e6), round(sta_list(r).out.time.getRate * 1e6)) * 1e-6;
                    end
                else
                    % It's a target

                    % recompute the parameters for the ref_time estimation
                    % not that in principle I can have up to num_trg_rec ref_time
                    % in case of multiple targets the reference times should be independent
                    % so here I keep the temporary rt0 rt1 r_rate var
                    % instead of ref_time_start, ref_time_stop, ref_rate
                    pt0 = max(p_time_start, round(sta_list(r).out.time.first.getRefTime(p_time_zero) * sta_list(r).out.time.getRate) / sta_list(r).out.time.getRate);
                    pt1 = min(p_time_stop, round(sta_list(r).out.time.last.getRefTime(p_time_zero) * sta_list(r).out.time.getRate) / sta_list(r).out.time.getRate);
                    pr = lcm(round(p_rate * 1e6), round(sta_list(r).out.time.getRate * 1e6)) * 1e-6;
                    pt0 = ceil(pt0 / pr) * pr;
                    pt1 = floor(pt1 / pr) * pr;

                    % return one p_time for each target
                    i = i + 1;
                    p_time(i) = GPS_Time(p_time_zero, (pt0 : pr : pt1));
                    p_time(i).toUnixTime();

                    id_sync{i} = nan(p_time(i).length, numel(id));
                    for rs = id % for each rec to sync
                        if ~sta_list(rs).out.isEmpty && ~(obs_type(rs) == 0 && (rs ~= r)) % if it's not another different target
                            [~, id_ref, id_rec] = intersect(round(sta_list(rs).out.time.getRefTime(p_time_zero) * 1e5)/1e5, (pt0 : pr : pt1));
                            id_sync{i}(id_rec, rs) = id_ref;
                        end
                    end
                end
            end
        end

        function bsl_ids = getBaselineId(n_rec)
            % Get id of all the combinations of the stations
            %
            % SYNTAX:
            %   bsl_id = GNSS_Station.getBaselineId(n_rec);
            [r1, r2] = meshgrid(1 : n_rec, 1 : n_rec);
            bsl_ids = [serialize(tril(r1, -1)) serialize(tril(r2, -1))];
            bsl_ids = bsl_ids(bsl_ids(:, 1) > 0 & bsl_ids(:, 2) > 0, :);
        end
    end
    %% METHODS PLOTTING FUNCTIONS
    % ==================================================================================================================================================

    % Various debug images
    % name variant:
    %   c cartesian
    %   s scatter
    %   p polar
    %   m mixed
    methods (Access = public)
        function showAll(sta_list)
            % Try to show all the possible plots
            for i = 1:numel(sta_list)
                sta_list(i).out.showAll;
            end
        end

        function showObsStats(sta_list)
            % Show statistics about the observations stored in the object
            %
            % SYNTAX
            %   this.showObsStats()

            for s = 1 : numel(sta_list)
                sta_list(s).work.showObsStats();
            end
        end

        function showProcessingQualityInfo(sta_list)
            % Show quality info about the receiver processing
            % SYNTAX this.showProcessingQualityInfo();

            for r = 1 : length(sta_list)
                if ~sta_list(r).isEmpty() && ~sta_list(r).out.isEmpty()
                    rec_out = sta_list(r).out;
                    rec_out.showProcessingQualityInfo();
                end
            end
        end

        function showPositionENU(sta_list, one_plot)
            % Plot East North Up coordinates of the receiver (as estimated by initDynamicPositioning
            % SYNTAX this.plotPositionENU();
            if nargin == 1
                one_plot = false;
            end

            for r = 1 : length(sta_list)
                rec = sta_list(r).out;
                if ~rec.isEmpty()
                    rec.showPositionENU(one_plot);
                end
            end
        end

        function showPositionXYZ(sta_list, one_plot)
            % Plot X Y Z coordinates of the receiver (as estimated by initDynamicPositioning
            % SYNTAX this.plotPositionXYZ();
            if nargin == 1
                one_plot = false;
            end

            for r = 1 : length(sta_list)
                rec = sta_list(r).out;
                if ~isempty(rec)
                    rec.showPositionXYZ(one_plot);
                end
            end
        end

        function showPositionSigmas(sta_list, one_plot)
            % Show Sigmas of the solutions
            %
            % SYNTAX
            %   this.showPositionSigmas();

            if nargin == 1
                one_plot = false;
            end

            for r = 1 : length(sta_list)
                rec = sta_list(r).out;
                if ~isempty(rec)
                    rec.showPositionSigmas(one_plot);
                end
            end
        end

        function showMap(sta_list, new_fig)
            % Show Google Map of the stations
            %
            % CITATION:
            %   Pawlowicz, R., 2019. "M_Map: A mapping package for MATLAB", version 1.4k, [Computer software],
            %   available online at www.eoas.ubc.ca/~rich/map.html.
            %
            % INPUT
            %   new_fig     open a new figure
            %
            % SYNTAX
            %   sta_list.showMap(new_fig);
            if nargin < 2
                new_fig = true;
            end
            sta_list.showMapGoogle(new_fig);
        end

        function showMapDtm(sta_list, new_fig, resolution)
            % Show Map of the stations
            % downloading the DTM and showing it
            %
            % CITATION:
            %   Pawlowicz, R., 2019. "M_Map: A mapping package for MATLAB", version 1.4k, [Computer software],
            %   available online at www.eoas.ubc.ca/~rich/map.html.
            %
            % INPUT
            %   new_fig     open a new figure
            %   resolution  'high' / 'low'
            %
            % SYNTAX
            %   sta_list.showMapDtm(new_fig, resolution);
            if nargin < 2
                new_fig = true;
            end
            if new_fig
                f = figure('Visible', 'off');
            else
                f = gcf;
                hold on;
            end
            if (nargin < 3) || isempty(resolution)
                resolution = 'low';
            end
            % check accepted values (low / high)
            switch resolution
                case 'high'
                otherwise
                    resolution = 'low';
            end
            Logger.getInstance.addMarkedMessage('Preparing map, please wait...');
            
            maximizeFig(f);
            f.Color = [1 1 1];
            [lat, lon] = sta_list.getMedianPosGeodetic();

            % set map limits
            if numel(sta_list) == 1
                lon_lim = minMax(lon) + [-0.05 0.05];
                lat_lim = minMax(lat) + [-0.05 0.05];
            else
                lon_lim = minMax(lon); lon_lim = lon_lim + [-1 1] * diff(lon_lim)/15;
                lat_lim = minMax(lat); lat_lim = lat_lim + [-1 1] * diff(lat_lim)/15;
            end
            nwse = [lat_lim(2), lon_lim(1), lat_lim(1), lon_lim(2)];
            clon = nwse([2 4]) + [-0.02 0.02];
            clat = nwse([3 1]) + [-0.02 0.02];

            %m_proj('equidistant','lon',clon,'lat',clat);   % Projection
            m_proj('utm', 'lon',lon_lim,'lat',lat_lim);   % Projection
            axes
            cmap = flipud(gray(1000)); colormap(cmap(150: end, :));
            
            % retrieve external DTM
            try
                [dtm, lat_dtm, lon_dtm] = Core.getRefDTM(nwse, 'ortho', resolution);
                dtm = flipud(dtm);
                % comment the following line to have bathimetry
                dtm(dtm < 0) = nan; % - 1/3 * max(dtm(:));
            
                % uncomment the following line to have colors
                % colormap(Cmap.adaptiveTerrain(minMax(dtm(:))));
                drawnow;
                
                [shaded_dtm, x, y] = m_shadedrelief(lon_dtm, lat_dtm, dtm, 'nan', [0.98, 0.98, 1]);
                %h_dtm = m_pcolor(lon_dtm, lat_dtm, dtm);
                %h_dtm.CData = shaded_dtm;
                m_image(lon_dtm, lat_dtm, shaded_dtm); 
            catch
                % use ETOPO1 instead
                m_etopo2('shadedrelief','gradient', 3);
            end

            % read shapefile
            shape = 'none';
            if (~strcmp(shape,'none'))
                if (~strcmp(shape,'coast')) && (~strcmp(shape,'fill'))
                    if (strcmp(shape,'10m'))
                        M = m_shaperead('countries_10m');
                    elseif (strcmp(shape,'30m'))
                        M = m_shaperead('countries_30m');
                    else
                        M = m_shaperead('countries_50m');
                    end
                    [x_min, y_min] = m_ll2xy(min(lon_lim), min(lat_lim));
                    [x_max, y_max] = m_ll2xy(max(lon_lim), max(lat_lim));
                    for k = 1 : length(M.ncst)
                        lam_c = M.ncst{k}(:,1);
                        ids = lam_c <  min(lon);
                        lam_c(ids) = lam_c(ids) + 360;
                        phi_c = M.ncst{k}(:,2);
                        [x, y] = m_ll2xy(lam_c, phi_c);
                        if sum(~isnan(x))>1
                            x(find(abs(diff(x)) >= abs(x_max - x_min) * 0.90) + 1) = nan; % Remove lines that occupy more than th 90% of the plot
                            line(x,y,'color', [0.3 0.3 0.3]);
                        end
                    end
                else
                    if (strcmp(shape,'coast'))
                        m_coast('line','color', lineCol);
                    else
                        m_coast('patch',lineCol);
                    end
                end
            end
            
            hold on;
            
            m_grid('box','fancy','tickdir','in', 'fontsize', 16);
            % m_ruler(1.1, [.05 .40], 'tickdir','out','ticklen',[.007 .007], 'fontsize',14);
            drawnow
            m_ruler([.7 1], -0.05, 'tickdir','out','ticklen',[.007 .007], 'fontsize',14);
            [x, y] = m_ll2xy(lon, lat);
            
            plot(x(:), y(:),'.k', 'MarkerSize', 5); hold on;            
            % Label BG (in background w.r.t. the point)
            for r = 1 : numel(sta_list)
                name = upper(sta_list(r).getMarkerName4Ch());
                text(x(r), y(r), char(32 * ones(1, 4 + 2 * length(name), 'uint8')), ...
                    'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0], ...
                    'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                    'Margin', 2, 'LineWidth', 2, ...
                    'HorizontalAlignment','left');
            end
            
            for r = 1 : numel(sta_list)
                plot(x(r), y(r), '.', 'MarkerSize', 45, 'Color', Core_UI.getColor(r, numel(sta_list)));
            end
            plot(x(:), y(:), '.k', 'MarkerSize', 5);
            plot(x(:), y(:), 'ko', 'MarkerSize', 15, 'LineWidth', 2);
           
            for r = 1 : numel(sta_list)
                name = upper(sta_list(r).getMarkerName4Ch());
                t = text(x(r), y(r), ['   ' name], ...
                    'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0], ...
                    ...%'FontWeight', 'bold', 'FontSize', 10, 'Color', [0 0 0], ...
                    ...%'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                    'Margin', 2, 'LineWidth', 2, ...
                    'HorizontalAlignment','left');
                %t.Units = 'pixels';
                %t.Position(1) = t.Position(1) + 20 + 10 * double(numel(sta_list) == 1);
                %t.Units = 'data';
            end
            f.Visible = 'on';
            title(sprintf('Receiver position\\fontsize{5} \n'), 'FontSize', 16);
            %xlabel('Longitude [deg]');
            %ylabel('Latitude [deg]');
            ax = gca; ax.FontSize = 16;
            Logger.getInstance.addStatusOk('The map is ready ^_^');
        end

        function showMapGoogle(sta_list, new_fig)
            % Show Google Map of the stations
            %
            % CITATION:
            %   Pawlowicz, R., 2019. "M_Map: A mapping package for MATLAB", version 1.4k, [Computer software],
            %   available online at www.eoas.ubc.ca/~rich/map.html.
            %
            % INPUT
            %   new_fig     open a new figure
            %
            % SYNTAX
            %   sta_list.showMapGoogle(new_fig);
            if nargin < 2
                new_fig = true;
            end
            if new_fig
                f = figure('Visible', 'off');
            else
                f = gcf;
                hold on;
            end
            if (nargin < 3) || isempty(resolution)
                resolution = 'low';
            end
            % check accepted values (low / high)
            switch resolution
                case 'high'
                otherwise
                    resolution = 'low';
            end
            Logger.getInstance.addMarkedMessage('Preparing map, please wait...');
            
            maximizeFig(f);
            f.Color = [1 1 1];
            [lat, lon] = sta_list.getMedianPosGeodetic();

            % set map limits
            if numel(sta_list) == 1
                lon_lim = minMax(lon) + [-0.05 0.05];
                lat_lim = minMax(lat) + [-0.05 0.05];
            else
                lon_lim = minMax(lon); lon_lim = lon_lim + [-1 1] * diff(lon_lim)/15;
                lat_lim = minMax(lat); lat_lim = lat_lim + [-1 1] * diff(lat_lim)/15;
            end
            nwse = [lat_lim(2), lon_lim(1), lat_lim(1), lon_lim(2)];
            clon = nwse([2 4]) + [-0.02 0.02];
            clat = nwse([3 1]) + [-0.02 0.02];

            axes
            xlim(lon_lim);
            ylim(lat_lim);
            [lon_ggl,lat_ggl, img_ggl] = plot_google_map('alpha', 0.95, 'maptype','satellite','refresh',0,'autoaxis',0);

            %m_proj('equidistant','lon',clon,'lat',clat);   % Projection
            m_proj('utm', 'lon',lon_lim,'lat',lat_lim);   % Projection                                
            drawnow
            m_image(lon_ggl, lat_ggl, img_ggl); 
            
            % read shapefile
            shape = 'none';
            if (~strcmp(shape,'none'))
                if (~strcmp(shape,'coast')) && (~strcmp(shape,'fill'))
                    if (strcmp(shape,'10m'))
                        M = m_shaperead('countries_10m');
                    elseif (strcmp(shape,'30m'))
                        M = m_shaperead('countries_30m');
                    else
                        M = m_shaperead('countries_50m');
                    end
                    [x_min, y_min] = m_ll2xy(min(lon_lim), min(lat_lim));
                    [x_max, y_max] = m_ll2xy(max(lon_lim), max(lat_lim));
                    for k = 1 : length(M.ncst)
                        lam_c = M.ncst{k}(:,1);
                        ids = lam_c <  min(lon);
                        lam_c(ids) = lam_c(ids) + 360;
                        phi_c = M.ncst{k}(:,2);
                        [x, y] = m_ll2xy(lam_c, phi_c);
                        if sum(~isnan(x))>1
                            x(find(abs(diff(x)) >= abs(x_max - x_min) * 0.90) + 1) = nan; % Remove lines that occupy more than th 90% of the plot
                            line(x,y,'color', [0.3 0.3 0.3]);
                        end
                    end
                else
                    if (strcmp(shape,'coast'))
                        m_coast('line','color', lineCol);
                    else
                        m_coast('patch',lineCol);
                    end
                end
            end
            
            hold on;
            
            m_grid('box','fancy','tickdir','in', 'fontsize', 16);
            % m_ruler(1.1, [.05 .40], 'tickdir','out','ticklen',[.007 .007], 'fontsize',14);
            drawnow
            m_ruler([.7 1], -0.05, 'tickdir','out','ticklen',[.007 .007], 'fontsize',14);
            [x, y] = m_ll2xy(lon, lat);
            
            plot(x(:), y(:),'.k', 'MarkerSize', 5); hold on;            
            % Label BG (in background w.r.t. the point)
            for r = 1 : numel(sta_list)
                name = upper(sta_list(r).getMarkerName4Ch());
                text(x(r), y(r), char(32 * ones(1, 4 + 2 * length(name), 'uint8')), ...
                    'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0], ...
                    'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                    'Margin', 2, 'LineWidth', 2, ...
                    'HorizontalAlignment','left');
            end
            
            for r = 1 : numel(sta_list)
                plot(x(r), y(r), '.', 'MarkerSize', 45, 'Color', Core_UI.getColor(r, numel(sta_list)));
            end
            plot(x(:), y(:), '.k', 'MarkerSize', 5);
            plot(x(:), y(:), 'ko', 'MarkerSize', 15, 'LineWidth', 2);
           
            for r = 1 : numel(sta_list)
                name = upper(sta_list(r).getMarkerName4Ch());
                t = text(x(r), y(r), ['   ' name], ...
                    'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0], ...
                    ...%'FontWeight', 'bold', 'FontSize', 10, 'Color', [0 0 0], ...
                    ...%'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                    'Margin', 2, 'LineWidth', 2, ...
                    'HorizontalAlignment','left');
                %t.Units = 'pixels';
                %t.Position(1) = t.Position(1) + 20 + 10 * double(numel(sta_list) == 1);
                %t.Units = 'data';
            end
            
            f.Visible = 'on';
            title(sprintf('Receiver position\\fontsize{5} \n'), 'FontSize', 16);
            %xlabel('Longitude [deg]');
            %ylabel('Latitude [deg]');
            ax = gca; ax.FontSize = 16;
            Logger.getInstance.addStatusOk('The map is ready ^_^');
        end
        
        function showMapGoogleLegacy(sta_list, new_fig)
            % Show Google Map of the stations
            % Old version without m_map
            %
            % SYNTAX
            %   sta_list.showMapGoogle(new_fig);
            if nargin < 2
                new_fig = true;
            end
            if new_fig
                f = figure;
            else
                f = gcf;
                hold on;
            end
            maximizeFig(f);
            [lat, lon] = sta_list.getMedianPosGeodetic();

            plot(lon(:), lat(:),'.k', 'MarkerSize', 5); hold on;            
            % Label BG (in background w.r.t. the point)
            for r = 1 : numel(sta_list)
                text(lon(r), lat(r), '                ', ...
                    'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0], ...
                    'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                    'Margin', 2, 'LineWidth', 2, ...
                    'HorizontalAlignment','left');
            end
            
            for r = 1 : numel(sta_list)
                plot(lon(r), lat(r), '.', 'MarkerSize', 45, 'Color', Core_UI.getColor(r, numel(sta_list)));
            end
            plot(lon(:), lat(:), '.k', 'MarkerSize', 5);
            plot(lon(:), lat(:), 'ko', 'MarkerSize', 15, 'LineWidth', 2);

            if numel(sta_list) == 1
                lon_lim = minMax(lon);
                lat_lim = minMax(lat);
                lon_lim(1) = lon_lim(1) - 0.05;
                lon_lim(2) = lon_lim(2) + 0.05;
                lat_lim(1) = lat_lim(1) - 0.05;
                lat_lim(2) = lat_lim(2) + 0.05;
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

            for r = 1 : numel(sta_list)
                name = upper(sta_list(r).getMarkerName4Ch());
                t = text(lon(r), lat(r), ['   ' name], ...
                    'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0 0], ...
                    ...%'FontWeight', 'bold', 'FontSize', 10, 'Color', [0 0 0], ...
                    ...%'BackgroundColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], ...
                    'Margin', 2, 'LineWidth', 2, ...
                    'HorizontalAlignment','left');
                %t.Units = 'pixels';
                %t.Position(1) = t.Position(1) + 20 + 10 * double(numel(sta_list) == 1);
                %t.Units = 'data';
            end

            plot_google_map('alpha', 0.95, 'MapType', 'satellite');
            title(sprintf('Receiver position\\fontsize{5} \n'), 'FontSize', 16);
            xlabel('Longitude [deg]');
            ylabel('Latitude [deg]');
            ax = gca; ax.FontSize = 16;
            Logger.getInstance.addStatusOk('The map is ready ^_^');
        end

        function showCMLRadarMapAniRec(sta_list)
            try
                cml = CML();
                cml.showRadarMapAniRec(sta_list);
            catch
                sta_list(1).log.addError('You need GReD utilities to have this features');
            end
        end
        
        function showAniMapTropoScatter(sta_list, par_name, new_fig, epoch, flag_export)
            % Show a tropo map with all the station in sta_list
            %
            % INPUT
            %   tropo_par   accepted tropo parameter:
            %               - 'zwd'
            %               - 'ztd'
            %   new_fig     if true or missing open a new figure
            %   epoch       list of epoch to display (pay attention that there is a subsampling rate in the function 1:10:end)
            %   flag_export if true try to export a video (the frames are not going to be seen)
            %               the video file will be saved in the out folder specified in the project
            %
            % SYNTAX
            %   sta_list.showMapTropo(<new_fig>, <epoch>, <flag_export>);
            
            ss_rate = 10; % subsample rate for show;

            if nargin < 3 || isempty(new_fig)
                new_fig = true;
            end
            if new_fig
                fig_handle = figure;
            else
                fig_handle = gcf;
                hold on;
            end
            if nargin < 5
                flag_export = false;
            end

            maximizeFig(fig_handle);

            switch lower(par_name)
                case 'ztd'
                    [res_tropo, s_time] = sta_list.getZtd_mr();
                    par_str = 'ZTD';
                    par_str_short = 'ZTD';
                case 'ztd_red'
                    [res_tropo, s_time] = sta_list.getReducedZtd_mr();
                    par_str = 'reduced ZTD';
                    par_str_short = 'RedZTD';
                case 'zwd'
                    [res_tropo, s_time] = sta_list.getZwd_mr();
                    par_str = 'ZWD';
                    par_str_short = 'ZWD';
                case 'gn'
                case 'ge'
                case 'pwv'
                case 'zhd'
                case 'nsat'
            end
            res_tropo = res_tropo * 1e2;
                
            if nargin < 3 || isempty(epoch)
                epoch = 1 : s_time.length();
            end

            coo = Coordinates.fromXYZ(sta_list.getMedianPosXYZ);
            [lat, lon] = coo.getGeodetic;

            sh = scatter(lon(:)./pi*180, lat(:)./pi*180, 100, res_tropo(epoch(1),:)', 'filled');
            hold on;
            % plot(lon(:)./pi*180, lat(:)./pi*180,'ko','MarkerSize', 15, 'LineWidth', 2);
            caxis([min(res_tropo(:)) max(res_tropo(:))]);
            colormap(gat);
            colorbar;

            lon_lim = xlim();
            lon_lim(1) = lon_lim(1) - 0.1;
            lon_lim(2) = lon_lim(2) + 0.1;
            lat_lim = ylim();
            lat_lim(1) = lat_lim(1) - 0.1;
            lat_lim(2) = lat_lim(2) + 0.1;

            xlim(lon_lim);
            ylim(lat_lim);

            ax = fig_handle.Children(end);
            ax.FontSize = 20;
            ax.FontWeight = 'bold';
            if new_fig
                if FTP_Downloader.checkNet()
                    plot_google_map('alpha', 0.95, 'MapType', 'satellite');
                end
                xlabel('Longitude [deg]');
                ylabel('Latitude [deg]');
            end
            th = title(sprintf([par_str ' variations [cm] map @%s'], s_time.getEpoch(1).toString('yyyy-mm-dd HH:MM:SS')), 'FontSize', 30);
            Core_UI.insertLogo(fig_handle, 'SouthEast');

            if flag_export
                im = {};
                frame = getframe(fig_handle);
                im{1} = frame(1:2:end,1:2:end,:); % subsample (1:2)
                fig_handle.Visible = 'off';
                Core.getLogger.addMarkedMessage('Exporting video');
                fprintf('%5d/%5d', 0, 99999);
            end
            drawnow
            if numel(epoch) > 1
                epoch_list = (ss_rate + 1) : ss_rate : numel(epoch);
                for i = 1 : numel(epoch_list)
                    e = epoch_list(i);
                    if any(res_tropo(epoch(e),:))
                        th.String = sprintf([par_str ' variations [cm] map %s'], s_time.getEpoch(epoch(e)).toString('yyyy-mm-dd HH:MM:SS'));
                        sh.CData = res_tropo(epoch(e),:)';
                        if not(flag_export)
                            drawnow
                        end
                    end
                    if flag_export
                        fprintf('%s%5d/%5d',char(8 * ones(1,11)), i,numel(epoch_list));
                        frame = getframe(fig_handle);
                        im{i + 1} = frame(1:2:end,1:2:end,:); % subsample (1:2)
                    end
                end
            end

            if flag_export
                fprintf('%s',char(8 * ones(1,11)));
                if ismac() || ispc()
                    % Better compression on Mac > 10.7 and Win > 7
                    video_out = VideoWriter(fullfile(Core.getState.getOutDir, ['AniMap' par_str_short '.mp4']), 'MPEG-4');
                else
                    % Linux doesn't have mp4 compression avaiable
                    video_out = VideoWriter(fullfile(Core.getState.getOutDir, ['AniMap' par_str_short '.avi']));
                end
                video_out.FrameRate = 30;
                video_out.Quality = 91;
                open(video_out);
                for i = 1 : numel(im)
                    writeVideo(video_out, im{i});
                end
                close(video_out);
                Core.getLogger.addStatusOk(sprintf('"%s" done ^_^', fullfile(Core.getState.getOutDir, video_out.Filename)));
                close(fig_handle)
            end
        end
       
        function showAniMapTropoInterp(sta_list_full, par_name, nwse, rate, flag_dtm, flag_export)
            % Show a tropo map with all the station in sta_list
            %
            % INPUT
            %   tropo_par   accepted tropo parameter:
            %               - 'zwd'
            %               - 'ztd'
            %   nwse        Nort West South East coordinates
            %   rate        rate in seconds, nearest to closest observation 
            %               it should be a subsample of the data rate (e.g. 300 with 30s data)
            %   flag_dtm    flag to add height_correction (default == false)
            %   flag_export if true try to export a video (the frames are not going to be seen)
            %               the video file will be saved in the out folder specified in the project
            %
            % SYNTAX
            %   sta_list.showAniMapTropoInterp(par_name, <new_fig>, <rate>, <flag_dtm>, <flag_export>);
            %
            % EXAMPLE
            %   % over Japan
            %   sta_list.showAniMapTropoInterp('ZWD', [45.8, 123.5, 23, 146.5], 200, 2, false);
            
            switch lower(par_name)
                case 'ztd'
                    par_str = 'ZTD';
                    par_str_short = 'ZTD';
                case 'zwd'
                    par_str = 'ZWD';
                    par_str_short = 'ZWD';
                case 'gn'
                case 'ge'
                case 'pwv'
                    par_str = 'PWV';
                    par_str_short = 'PWV';
                case 'zhd'
                case 'nsat'
            end                        

            fig_handle = figure;
            
            if nargin < 4 || isempty(rate)
                rate = 300;
            end
            if nargin < 5
                flag_dtm = false;
            end
            if nargin < 6
                flag_export = false;
            end

            maximizeFig(fig_handle);
            
            fig_handle.Visible = 'off';
            fig_handle.Color = [1 1 1];

            % Set map projection / limits
            
            [lat, lon] = sta_list_full.getMedianPosGeodetic();
            margin = 0.5;
            id_ok = (lat >= (nwse(3) - margin)) & (lat <= (nwse(1) + margin)) & ...
                (lon >= (nwse(2) - margin)) & (lon <= (nwse(4) + margin));
            sta_list = sta_list_full(id_ok);
            
            if nargin < 3 || isempty(nwse)
                
                % set map limits
                if numel(sta_list) == 1
                    lon_lim = minMax(lon) + [-0.05 0.05];
                    lat_lim = minMax(lat) + [-0.05 0.05];
                else
                    lon_lim = minMax(lon); lon_lim = lon_lim + [-1 1] * diff(lon_lim)/15;
                    lat_lim = minMax(lat); lat_lim = lat_lim + [-1 1] * diff(lat_lim)/15;
                end
                nwse = [lat_lim(2), lon_lim(1), lat_lim(1), lon_lim(2)];
            else
                lon_lim = nwse([2 4]);
                lat_lim = nwse([3 1]);                
            end
            clon = nwse([2 4]) + [-0.02 0.02];
            clat = nwse([3 1]) + [-0.02 0.02];

            if flag_dtm == 2
                subplot(1,2,1);
            end
            
            for i = 1 : iif(flag_dtm == 2, 2, 1)
                if flag_dtm == 2
                    subplot(1,2,i);
                end
                %m_proj('equidistant','lon',clon,'lat',clat);   % Projection
                m_proj('utm', 'lon',lon_lim,'lat',lat_lim);   % Projection
                axes
                cmap = flipud(gray(1000)); colormap(cmap(150: end, :));
                drawnow;
            end
            
            % retrieve external DTM
            try
                [dtm, lat_dtm, lon_dtm] = Core.getRefDTM(nwse, 'ortho', 'low');
                dtm = flipud(dtm);
                % comment the following line to have bathimetry
                dtm(dtm < 0) = nan; % - 1/3 * max(dtm(:));
                
                % uncomment the following line to have colors
                % colormap(Cmap.adaptiveTerrain(minMax(dtm(:))));
                % drawnow;
                
                [shaded_dtm, x, y] = m_shadedrelief(lon_dtm, lat_dtm, dtm, 'nan', [0.98, 0.98, 1]);
                %h_dtm = m_pcolor(lon_dtm, lat_dtm, dtm);
                %h_dtm.CData = shaded_dtm;
                for i = 1 : iif(flag_dtm == 2, 2, 1)
                    if flag_dtm == 2
                        subplot(1,2,i);
                    end
                    m_image(lon_dtm, lat_dtm, shaded_dtm);
                end
            catch
                % use ETOPO1 instead
                for i = 1 : iif(flag_dtm == 2, 2, 1)
                    if flag_dtm == 2
                        subplot(1,2,i);
                    end
                    m_etopo2('shadedrelief','gradient', 3);
                end
            end
            
            for i = 1 : iif(flag_dtm == 2, 2, 1)
                if flag_dtm == 2
                    subplot(1,2,i);
                end
                % read shapefile
                shape = 'none';
                if (~strcmp(shape,'none'))
                    if (~strcmp(shape,'coast')) && (~strcmp(shape,'fill'))
                        if (strcmp(shape,'10m'))
                            M = m_shaperead('countries_10m');
                        elseif (strcmp(shape,'30m'))
                            M = m_shaperead('countries_30m');
                        else
                            M = m_shaperead('countries_50m');
                        end
                        [x_min, y_min] = m_ll2xy(min(lon_lim), min(lat_lim));
                        [x_max, y_max] = m_ll2xy(max(lon_lim), max(lat_lim));
                        for k = 1 : length(M.ncst)
                            lam_c = M.ncst{k}(:,1);
                            ids = lam_c <  min(lon);
                            lam_c(ids) = lam_c(ids) + 360;
                            phi_c = M.ncst{k}(:,2);
                            [x, y] = m_ll2xy(lam_c, phi_c);
                            if sum(~isnan(x))>1
                                x(find(abs(diff(x)) >= abs(x_max - x_min) * 0.90) + 1) = nan; % Remove lines that occupy more than th 90% of the plot
                                line(x,y,'color', [0.3 0.3 0.3]);
                            end
                        end
                    else
                        if (strcmp(shape,'coast'))
                            m_coast('line','color', lineCol);
                        else
                            m_coast('patch',lineCol);
                        end
                    end
                end            
                hold on;
                
                % Enable box
                m_grid('box','fancy','tickdir','in', 'fontsize', 16);
                % m_ruler(1.1, [.05 .40], 'tickdir','out','ticklen',[.007 .007], 'fontsize',14);
                drawnow
                m_ruler([.7 1], -0.08, 'tickdir','out','ticklen',[.007 .007], 'fontsize',14);
            end
                        
            [tropo_grid, x_grid, y_grid, time, tropo_height_correction, tropo_clim] = sta_list.getTropoMap(par_name, rate);
            if flag_dtm == 1
                tropo_grid = tropo_grid + tropo_height_correction;
            end
            
            if flag_dtm == 2
               ax = subplot(1,2,1);
            end
            imh = m_pcolor(x_grid, y_grid, tropo_grid(:,:,1));
            imh.FaceAlpha = 0.95;
            caxis(tropo_clim(1,:));
            cmap = Cmap.get('c51',512);
            colormap(flipud(cmap(2:end,:)));
            % redraw boxes
            m_grid('box','fancy','tickdir','in', 'fontsize', 16);
            %colormap(flipud(gat(1024, false)));
            %colormap(Cmap.get('viridis', 32));
            if flag_dtm == 2  
                cax = m_contfbar([.05 .55], 0, tropo_clim(1, 1), tropo_clim(1) : (diff(tropo_clim(1,:)) / size(cmap,1)) : tropo_clim(1, 2) ,'edgecolor','none','endpiece','no', 'fontsize', 16);                xlabel(cax,'cm','color','k');
            else
                cax = m_contfbar([.15 .55], -0.05, tropo_clim(1, 1), tropo_clim(1) : (diff(tropo_clim(1,:)) / size(cmap,1)) : tropo_clim(1, 2) ,'edgecolor','none','endpiece','no', 'fontsize', 16);                xlabel(cax,'cm','color','k');
            end
            xlabel(cax,'cm','color','k');
            
            % ax = fig_handle.Children(end);
            % ax.FontSize = 20;
            % ax.FontWeight = 'bold';
            % if new_fig
            %     if FTP_Downloader.checkNet()
            %         plot_google_map('alpha', 0.65, 'MapType', 'satellite');
            %     end
            %     xlabel('Longitude [deg]');
            %     ylabel('Latitude [deg]');
            % end
            
            th = title(sprintf([par_str ' map @%s at sea level\\fontsize{5} \n'], time.getEpoch(1).toString('yyyy-mm-dd HH:MM:SS')), 'FontSize', 20);
            
            if flag_dtm == 2  
                %tropo_clim(2,:) = [max(0, tropo_clim(1) + min(tropo_height_correction(:))) (tropo_clim(2) + max(tropo_height_correction(:)))];
                % uniform axes
                ax2 = subplot(1,2,2);
                imh2 = m_pcolor(x_grid, y_grid, tropo_grid(:,:,1) + tropo_height_correction);
                imh2.FaceAlpha = 0.95;
                caxis(tropo_clim(2,:)); 
                %colormap(Core_UI.CMAP_51(2:end,:));
                %colormap(flipud(gat(1024, false)));
                %colormap(gat2);                            
                cmap = Cmap.get('c51',512);
                colormap(flipud(cmap(2:end,:)));
                % redraw boxes
                m_grid('box','fancy','tickdir','in', 'fontsize', 16);
                % ax2.FontSize = 20;
                % ax2.FontWeight = 'bold';
                % if new_fig
                %    if FTP_Downloader.checkNet()
                %        plot_google_map('alpha', 0.65, 'MapType', 'satellite');
                %    end
                %    xlabel('Longitude [deg]');
                %    ylabel('Latitude [deg]');
                %end
                cax2 = m_contfbar([.05 .55], 0, tropo_clim(1, 1), tropo_clim(1) : (diff(tropo_clim(1,:)) / size(cmap,1)) : tropo_clim(1, 2) ,'edgecolor','none','endpiece','no', 'fontsize', 16);                xlabel(cax,'cm','color','k');
                th2 = title(cax2, sprintf('at ground level\\fontsize{5} \n'), 'FontSize', 20);
            end
            
            fig_handle.Visible = 'on';
            %Core.getLogger.addMarkedMessage('Press any key to start playing');
            %pause

            % Add logos
            if flag_export
                fprintf('Stopped in debug mode to check the export size and position of the elements\nType dbcont to continue ')
                % fh = gcf; fh.Units = 'pixel'; fh.Position([3 4]) = [1100 960];
                keyboard % to check before export that everything is aligned
                Core_UI.insertLogo(fig_handle, 'SouthEast');
                warning off;                
                im = {};
                fig_handle.Visible = 'off';
                Core.getLogger.addMarkedMessage('Exporting video');
                fprintf('%5d/%5d', 0, 99999);
                
                if ismac() || ispc()
                    % Better compression on Mac > 10.7 and Win > 7
                    video_out = VideoWriter(fullfile(Core.getState.getOutDir, ['AniMap' par_str_short 'Interp.mp4']), 'MPEG-4');
                else
                    % Linux doesn't have mp4 compression avaiable
                    video_out = VideoWriter(fullfile(Core.getState.getOutDir, ['AniMap' par_str_short 'Interp.avi']));
                end
                video_out.FrameRate = 30;
                video_out.Quality = 66;
                open(video_out);
            else
                Core_UI.insertLogo(fig_handle, 'SouthEast');
                fig_handle.Visible = 'on';
            end
            drawnow
            
            for i = 1 : time.length
                if any(serialize(tropo_grid(:,:,i)))
                    th.String = sprintf([par_str ' [cm] map %s at sea level'], time.getEpoch(i).toString('yyyy-mm-dd HH:MM:SS'));
                    imh.CData = tropo_grid(:,:,i);
                    %imh.AlphaData = ~isnan(tropo_grid(:,:,i));
                    if flag_dtm == 2
                        imh2.CData = tropo_grid(:,:,i) + tropo_height_correction;
                        %imh2.AlphaData = imh.AlphaData;
                    end
                    if not(flag_export)
                        drawnow
                    end
                end
                if flag_export
                    fprintf('%s%5d/%5d',char(8 * ones(1,11)), i, time.length);
                    frame = getframe(fig_handle);
                    ss = 1; % subsample (1:2)
                    writeVideo(video_out, frame(1:ss:end,1:ss:end,:)); 
                end
            end
            
            if flag_export
                fprintf('%s',char(8 * ones(1,11)));
                close(video_out);
                Core.getLogger.addStatusOk(sprintf('"%s" done ^_^', fullfile(Core.getState.getOutDir, video_out.Filename)));
                close(fig_handle);
                warning on;
            end
        end

        function showDt(this)
            % Plot Clock error
            %
            % SYNTAX
            %   sta_list.plotDt

            for r = 1 : size(this, 2)
                rec = this(r);
                if ~isempty(rec)
                    rec.out.showDt();
                end
            end
        end

        function f_handle = showQuality_p(sta_list, type, flag_smooth)
            % Plot Signal to Noise Ration in a skyplot
            % SYNTAX f_handles = this.plotSNR(sys_c)

            % SNRs
            if nargin < 2
                type = 'snr';
            end

            f_handle = [];

            for r = 1 : numel(sta_list)
                if ~sta_list(r).out.isEmpty
                    rec = sta_list(r).out;
                    [quality, az, el] = rec.getQuality();
                else
                    rec = sta_list(r).work;
                    [quality, az, el] = rec.getQuality(type);
                end

                if nargin > 2 && flag_smooth
                    quality = Receiver_Commons.smoothSatData([],[],zero2nan(quality), [], 'spline', 900 / this.getRate, 10); % smoothing Quality => to be improved
                end

                if (numel(az) ~= numel(quality))
                    log = Logger.getInstance();
                    log.addError('Number of elements for az different from quality data\nPlotting id not possible');
                else
                    f = figure; f.Name = sprintf('%03d: %s', f.Number, upper(type)); f.NumberTitle = 'off';
                    f_handle(r) = f;
                    id_ok = (~isnan(quality));
                    polarScatter(serialize(az(id_ok)) / 180 * pi, serialize(90 - el(id_ok)) / 180 * pi, 45, serialize(quality(id_ok)), 'filled');
                    colormap(jet);  cax = caxis();
                    switch type
                        case 'snr'
                            caxis([min(cax(1), 10), max(cax(2), 55)]);
                            setColorMap([10 55], 0.9);
                    end
                    colorbar();
                    h = title(sprintf('%s - receiver %s', upper(type), sta_list(r).getMarkerName4Ch()), 'interpreter', 'none');
                    h.FontWeight = 'bold'; h.Units = 'pixels';
                    h.Position(2) = h.Position(2) + 20; h.Units = 'data';
                end
            end
        end

        function showResPerSat(sta_list)
            % Plot Satellite Residuals
            % As scatter per satellite
            % (work data only)
            %
            % SYNTAX
            %   sta_list.showResPerSat()

            for r = 1 : size(sta_list, 2)
                rec = sta_list(r);
                if ~isempty(rec)
                    if ~rec.out.isEmpty
                        rec.out.showResPerSat();
                    else
                        rec.work.showResPerSat();
                    end
                end
            end
        end

        function showRes(sta_list)
            % Plot Satellite Residuals
            %
            % SYNTAX
            %   sta_list.showRes()

            for r = 1 : size(sta_list, 2)
                rec = sta_list(r);
                if ~isempty(rec)
                    if ~rec.out.isEmpty
                        rec.out.showRes();
                    else
                        rec.work.showRes();
                    end
                end
            end
        end

        function showResMap(sta_list, step, sys_c_list, mode)
            % Plot Satellite Residuals as a map
            %
            % SYNTAX
            %   sta_list.showResMap(step)
            if nargin < 2 || isempty(step)
                step = 0.5;
            end
            for r = 1 : size(sta_list, 2)
                rec = sta_list(r);
                if ~isempty(rec)
                    if ~rec.out.isEmpty
                        cc = rec.out.getCC;
                    else
                        cc = rec.work.getCC;
                    end
                    if nargin < 3 || isempty(sys_c_list)
                        sys_c_list = cc.getActiveSysChar;
                    end
                    for ss = sys_c_list
                        if ~rec.out.isEmpty
                            [map, map_fill, ~, az_g, el_g] = rec.out.getResMap(step, 3, ss);
                        else
                            [map, map_fill, ~, az_g, el_g] = rec.work.getResMap(step, 3, ss);
                        end
                        % restore the original mean data where observations are present
                        %map_fill(~isnan(map)) = map(~isnan(map));
                        
                        f = figure;
                        f.Name = sprintf('%03d: ResMap %s@%c', f.Number, rec.getMarkerName4Ch, ss); f.NumberTitle = 'off';                        
                        if (nargin < 4) || isempty(mode)
                            mode = 'cart';
                        end
                        switch mode
                            case 'cart'
                                %% Cartesian projection
                                %img = imagesc(az_g, el_g, 1e3 * circshift(abs(map_fill), size(map_fill, 2) / 2, 2));
                                img = imagesc(az_g, el_g, 1e3 * map_fill);
                                set(gca,'YDir','normal');
                                grid on
                                image_alpha = 0.5; % everywhere 1 where obs are present
                                %img.AlphaData = (~isnan(circshift(abs(map), size(map, 2) / 2, 2)) * 0.7) + 0.3;
                                img.AlphaData = (~isnan(map) * (1 - image_alpha)) + image_alpha;
                                %colormap(flipud(hot)); colorbar(); caxis([0, 0.02]);
                                
                                %caxis(1e3 * [min(abs(map(:))) min(20, min(6*std(zero2nan(map(:)),'omitnan'), max(abs(zero2nan(map(:))))))]);
                                caxis(1e3 * perc(abs(map(:)), 0.99) * [-1 1]);
                                colormap(Cmap.get('PuOr', 256));
                                f.Color = [.95 .95 .95]; colorbar(); ax = gca; ax.Color = 'none';
                                h = title(sprintf('Satellites residuals [mm] - receiver %s - %c', ss, rec.getMarkerName4Ch, ss),'interpreter', 'none');
                                h.FontWeight = 'bold';
                                hl = xlabel('Azimuth [deg]'); hl.FontWeight = 'bold';
                                hl = ylabel('Elevation [deg]'); hl.FontWeight = 'bold';
                                %ax = gca;
                                %ax.PlotBoxAspectRatio = [1 1 1];
                                %ax.DataAspectRatio(2) = ax.DataAspectRatio(1);
                            case '3D'
                                %% 3D projection
%                                 clf
%                                 polarplot3d(1e3 * map_fill(1:2:end, 1:2:end),  'RadialRange',[-180 180] / 180 * pi, ...
%                                     'AxisLocation', 0, 'InterpMethod', 'cubic', ...
%                                     'PlotType', 'surfn', 'tickspacing', 15, ...
%                                     'GridColor', [0.7 0.7 0.7]);
                                polarplot3d(1e3 * map_fill, ...
                                    'AxisLocation', 0, 'InterpMethod', 'cubic', ...
                                    'PlotType', 'surfn', 'tickspacing', 15, ...
                                    'GridColor', [0.7 0.7 0.7]);
                                caxis(1e3 * perc(abs(map(:)), 0.95) * [-1 1]);
                                colormap(Cmap.get('RdGy', 256));
                                colorbar();
                                ax = gca;
                                ax.PlotBoxAspectRatio = [1 1 1];
                                ax.DataAspectRatio(2) = ax.DataAspectRatio(1);
                                smap = ax.Children(end);
                                smap.AlphaData = double(~isnan(map));
                                smap.AlphaData(smap.AlphaData == 0) = smap.AlphaData(smap.AlphaData == 0) + 0.5;
                                smap.FaceAlpha = 'flat';
                        end
                        
                    end
                end
            end
        end

        function showZtdSlant(sta_list, time_start, time_stop)
            for r = 1 : size(sta_list, 2)
                rec = sta_list(~sta_list(r).isEmpty, r);
                if isempty(rec)
                    log = Core.getLogger();
                    log.addWarning('ZTD and/or slants have not been computed');
                else
                    if nargin < 3
                        rec.out.showZtdSlant();
                    else
                        rec.out.showZtdSlant(time_start, time_stop);
                    end
                end
            end
        end

        function showPTH(sta_list)
            % Show plots for pressure, temperature and humidity
            %
            % SYNATAX
            %   sta_list.showPTH()
            [pressure, temperature, humidity, p_time, id_sync] = sta_list.getPTH_mr();

            f = figure;
            f.Name = sprintf('%03d: %s %s', f.Number, 'PTH', sta_list(1).out.getCC.sys_c); f.NumberTitle = 'off';
            set(f,'defaultAxesColorOrder', Core_UI.getColor(1 : numel(sta_list), numel(sta_list)));
            ax(1) = subplot(3,1,1);
            plot(p_time.getMatlabTime, pressure, '.');
            setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
            h = ylabel('Pressure [mbar]'); h.FontWeight = 'bold';

            outm = {};
            for r = 1 : numel(sta_list)
                outm{r} = sta_list(r).getMarkerName4Ch();
            end
            [~, icons] = legend(outm, 'Location', 'NorthEastOutside', 'interpreter', 'none');
            n_entry = numel(outm);
            icons = icons(n_entry + 2 : 2 : end);
            for i = 1 : numel(icons)
                icons(i).MarkerSize = 16;
            end

            ax(2) = subplot(3,1,2);
            plot(p_time.getMatlabTime, temperature, '.');
            setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
            h = ylabel('Temperaure [�C]'); h.FontWeight = 'bold';

            [~, icons] = legend(outm, 'Location', 'NorthEastOutside', 'interpreter', 'none');
            n_entry = numel(outm);
            icons = icons(n_entry + 2 : 2 : end);
            for i = 1 : numel(icons)
                icons(i).MarkerSize = 16;
            end

            ax(3) = subplot(3,1,3);
            plot(p_time.getMatlabTime, humidity, '.');
            setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
            h = ylabel('Humidity [%]'); h.FontWeight = 'bold';

            [~, icons] = legend(outm, 'Location', 'NorthEastOutside', 'interpreter', 'none');
            n_entry = numel(outm);
            icons = icons(n_entry + 2 : 2 : end);
            for i = 1 : numel(icons)
                icons(i).MarkerSize = 16;
            end

            linkaxes(ax, 'x');
            xlim([p_time.first.getMatlabTime() p_time.last.getMatlabTime()]);

        end

        function showTropoPar(sta_list, par_name, new_fig, sub_plot_nsat)
            % one function to rule them all

            [tropo, t] = sta_list.getTropoPar(par_name);
            if ~iscell(tropo)
                tropo = {tropo};
                t = {t};
            end

            rec_ok = false(numel(sta_list), 1);
            for r = 1 : size(sta_list, 2)
                rec_ok(r) = ~isempty(tropo{r});
            end

            sta_list = sta_list(rec_ok);
            tropo = tropo(rec_ok);
            t = t(rec_ok);

            if numel(sta_list) == 0
                log = Core.getLogger();
                log.addError('No valid troposphere is present in the receiver list');
            else
                if nargin < 3
                    new_fig = true;
                end

                if nargin < 4
                    sub_plot_nsat = false;
                end
                
                nsat_is_empty = false;
                tmp = sta_list.getNumSat; 
                if iscell(tmp)
                    for i = 1 : numel(tmp)
                        nsat_is_empty = nsat_is_empty || ~any(tmp{i});
                    end
                else
                    nsat_is_empty = ~any(tmp);
                end
                sub_plot_nsat = sub_plot_nsat && ~nsat_is_empty;
                
                if isempty(tropo)
                    sta_list(1).out.log.addWarning([par_name ' and slants have not been computed']);
                else
                    tlim = [inf -inf];
                    if new_fig
                        cc = Core.getState.getConstellationCollector;
                        f = figure; f.Name = sprintf('%03d: %s %s', f.Number, par_name, cc.sys_c); f.NumberTitle = 'off';
                        old_legend = {};
                    else
                        l = legend;
                        old_legend = get(l,'String');
                    end
                    if sub_plot_nsat
                        ax1 = subplot(3,1,1:2);
                    end
                    for r = 1 : numel(sta_list)
                        rec = sta_list(r);
                        if new_fig
                            if strcmp(par_name, 'nsat')
                                plot(t{r}.getMatlabTime(), zero2nan(tropo{r}'), '.-', 'LineWidth', 2, 'Color', Core_UI.getColor(r, size(sta_list, 2))); hold on;
                            else
                                plot(t{r}.getMatlabTime(), zero2nan(tropo{r}').*1e2, '.', 'LineWidth', 2, 'Color', Core_UI.getColor(r, size(sta_list, 2))); hold on;
                            end
                        else
                            if strcmp(par_name, 'nsat')
                                plot(t{r}.getMatlabTime(), zero2nan(tropo{r}'), '.-', 'LineWidth', 2); hold on;
                            else
                                plot(t{r}.getMatlabTime(), zero2nan(tropo{r}').*1e2, '.', 'LineWidth', 2); hold on;
                            end
                        end
                        outm{r} = rec(1).getMarkerName();
                        tlim(1) = min(tlim(1), t{r}.first.getMatlabTime());
                        tlim(2) = max(tlim(2), t{r}.last.getMatlabTime());
                        xlim(tlim);
                    end

                    outm = [old_legend, outm];
                    n_entry = numel(outm);

                    if n_entry < 20
                        if ~sub_plot_nsat
                            [~, icons] = legend(outm, 'Location', 'NorthEastOutside', 'interpreter', 'none');
                        else
                            loc = 'SouthWest';
                            if n_entry > 11
                                loc = 'NorthWestOutside';
                            end
                            [~, icons] = legend(outm, 'Location', loc, 'interpreter', 'none');
                        end
                        icons = icons(n_entry + 2 : 2 : end);

                        for i = 1 : numel(icons)
                            icons(i).MarkerSize = 16;
                        end
                    end

                    setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
                    h = ylabel([par_name ' [cm]']); h.FontWeight = 'bold';
                    grid on;
                    h = title(['Receiver ' par_name]); h.FontWeight = 'bold'; %h.Units = 'pixels'; h.Position(2) = h.Position(2) + 8; h.Units = 'data';
                    if sub_plot_nsat
                        ax2 = subplot(3,1,3);
                        for r = 1 : numel(sta_list)
                            rec = sta_list(r);
                            if new_fig
                                plot(t{r}.getMatlabTime(), zero2nan(rec.getNumSat'), '.-', 'LineWidth', 2, 'Color', Core_UI.getColor(r, size(sta_list, 2))); hold on;
                            end
                            outm{r} = rec(1).getMarkerName();
                            tlim(1) = min(tlim(1), t{r}.first.getMatlabTime());
                            tlim(2) = max(tlim(2), t{r}.last.getMatlabTime());
                            xlim(tlim);
                        end
                        setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
                        h = ylabel(['# sat']); h.FontWeight = 'bold';
                        grid on;
                        linkaxes([ax1 ax2], 'x');
                    end
                end
            end
        end

        function showNSat(sta_list, new_fig)
            % Show total number of satellites in view (epoch by epoch) for each satellite
            if nargin == 1
                new_fig = true;
            end
            sta_list.showTropoPar('nsat', new_fig, false)
        end

        function showNSatSS(sta_list)
            % Show total number of satellites in view (epoch by epoch) for each satellite

            for r = 1 : numel(sta_list)
                if ~(isempty(sta_list(r).out) || sta_list(r).out.isEmpty)
                    sta_list(r).out.showNSatSS();
                else
                    sta_list(r).work.showNSatSS();
                end
            end
        end

        function showZhd(sta_list, new_fig, sub_plot_nsat)
            % Display ZHD values
            %
            % INPUT:
            %   new_fig         flag to specify to open a new figure (default = true)
            %   sub_plot_nsat   flag to specify to subplot #sat      (default = true)
            %
            % SYNTAX:
            %   sta_list.showZhd(<new_fig = true>, <sub_plot_nsat = true>)

            if nargin <= 1 || isempty(new_fig)
                new_fig = true;
            end
            if nargin <= 2 || isempty(sub_plot_nsat)
                sub_plot_nsat = true;
            end
            sta_list.showTropoPar('ZHD', new_fig, sub_plot_nsat)
        end

        function showZwd(sta_list, new_fig, sub_plot_nsat)
            % Display ZWD values
            %
            % INPUT:
            %   new_fig         flag to specify to open a new figure (default = true)
            %   sub_plot_nsat   flag to specify to subplot #sat      (default = true)
            %
            % SYNTAX:
            %   sta_list.showZwd(<new_fig = true>, <sub_plot_nsat = true>)

            if nargin <= 1 || isempty(new_fig)
                new_fig = true;
            end
            if nargin <= 2 || isempty(sub_plot_nsat)
                sub_plot_nsat = true;
            end
            sta_list.showTropoPar('ZWD', new_fig, sub_plot_nsat)
        end

        function showPwv(sta_list, new_fig, sub_plot_nsat)
            % Display PWV values
            %
            % INPUT:
            %   new_fig         flag to specify to open a new figure (default = true)
            %   sub_plot_nsat   flag to specify to subplot #sat      (default = true)
            %
            % SYNTAX:
            %   sta_list.showPwv(<new_fig = true>, <sub_plot_nsat = true>)

            if nargin <= 1 || isempty(new_fig)
                new_fig = true;
            end
            if nargin <= 2 || isempty(sub_plot_nsat)
                sub_plot_nsat = true;
            end
            sta_list.showTropoPar('PWV', new_fig, sub_plot_nsat)
        end

        function showZtd(sta_list, new_fig, sub_plot_nsat)
            % Display ZTD values
            %
            % INPUT:
            %   new_fig         flag to specify to open a new figure (default = true)
            %   sub_plot_nsat   flag to specify to subplot #sat      (default = true)
            %
            % SYNTAX:
            %   sta_list.showZtd(<new_fig = true>, <sub_plot_nsat = true>)

            if nargin <= 1 || isempty(new_fig)
                new_fig = true;
            end
            if nargin <= 2 || isempty(sub_plot_nsat)
                sub_plot_nsat = true;
            end
            sta_list.showTropoPar('ZTD', new_fig, sub_plot_nsat)
        end

        function showGn(sta_list, new_fig, sub_plot_nsat)
            % Display ZTD Gradiet North values
            %
            % INPUT:
            %   new_fig         flag to specify to open a new figure (default = true)
            %   sub_plot_nsat   flag to specify to subplot #sat      (default = true)
            %
            % SYNTAX:
            %   sta_list.showGn(<new_fig = true>, <sub_plot_nsat = true>)

            if nargin <= 1 || isempty(new_fig)
                new_fig = true;
            end
            if nargin <= 2 || isempty(sub_plot_nsat)
                sub_plot_nsat = true;
            end
            sta_list.showTropoPar('GN', new_fig, sub_plot_nsat)
        end

        function showGe(sta_list, new_fig, sub_plot_nsat)
            % Display ZTD Gradiet East values
            %
            % INPUT:
            %   new_fig         flag to specify to open a new figure (default = true)
            %   sub_plot_nsat   flag to specify to subplot #sat      (default = true)
            %
            % SYNTAX:
            %   sta_list.showGe(<new_fig = true>, <sub_plot_nsat = true>)

            if nargin <= 1 || isempty(new_fig)
                new_fig = true;
            end
            if nargin <= 2 || isempty(sub_plot_nsat)
                sub_plot_nsat = true;
            end
            sta_list.showTropoPar('GE', new_fig, sub_plot_nsat)
        end

        function showZtdVsHeight(sta_list, degree)
            % Show Median ZTD of n_receivers vs Hortometric height
            %
            % SYNTAX
            %   sta_list.showZtdVsHeight();
            figure;
            med_ztd = median(sta_list.getZtd_mr * 1e2, 'omitnan')';
            subplot(2,1,1);
            [~, ~, ~, h_o] = Coordinates.fromXYZ(sta_list.getMedianPosXYZ()).getGeodetic;
            plot(h_o, med_ztd, '.', 'MarkerSize', 20); hold on;
            ylabel('Median ZTD [cm]');
            xlabel('Elevation [m]');
            title('ZTD vs Height')

            if nargin == 1
                degree = 5;
            end
            y_out = Core_Utils.interp1LS(h_o, med_ztd, degree, h_o);
            plot(sort(h_o), Core_Utils.interp1LS(h_o, med_ztd, degree, sort(h_o)), '-', 'Color', Core_UI.COLOR_ORDER(3,:), 'LineWidth', 2);
            subplot(2,1,2);
            plot(h_o, med_ztd - y_out, '.', 'MarkerSize', 20);

            ylabel('residual [cm]');
            xlabel('Elevation [m]');
            title('reduced ZTD vs Height')

            sta_strange = find(abs(med_ztd - y_out) > 8);
            if ~isempty(sta_strange)
                Core.getLogger.addMessage('Strange station detected');
                for s = 1 : numel(sta_strange)
                    Core.getLogger.addMessage(sprintf(' %d - %s', sta_strange(s), sta_list(sta_strange(s)).getMarkerName()));
                end
            end
        end

        function showZwdVsHeight(sta_list, degree)
            % Show Median ZTD of n_receivers vs Hortometric height
            %
            % SYNTAX
            %   sta_list.showZwdVsHeight();
            figure;
            med_zwd = median(sta_list.getZwd_mr * 1e2, 'omitnan')';
            subplot(2,1,1);
            [~, ~, ~, h_o] = Coordinates.fromXYZ(sta_list.getMedianPosXYZ()).getGeodetic;
            plot(h_o, med_zwd, '.', 'MarkerSize', 20); hold on;
            ylabel('Median ZWD [cm]');
            xlabel('Elevation [m]');
            title('ZWD vs Height')

            if nargin == 1
                degree = 5;
            end
            y_out = Core_Utils.interp1LS(h_o, med_zwd, degree, h_o);
            plot(sort(h_o), Core_Utils.interp1LS(h_o, med_zwd, degree, sort(h_o)), '-', 'Color', Core_UI.COLOR_ORDER(3,:), 'LineWidth', 2);
            subplot(2,1,2);
            plot(h_o, med_zwd - y_out, '.', 'MarkerSize', 20);

            ylabel('residual [cm]');
            xlabel('Elevation [m]');
            title('reduced ZWD vs Height')

            sta_strange = find(abs(med_zwd - y_out) > 8);
            if ~isempty(sta_strange)
                Core.getLogger.addMessage('Strange station detected');
                for s = 1 : numel(sta_strange)
                    Core.getLogger.addMessage(sprintf(' %d - %s', sta_strange(s), sta_list(sta_strange(s)).getMarkerName()));
                end
            end
        end

        function showMedianTropoPar(this, par_name, new_fig)
            % one function to rule them all
            rec_ok = false(size(this,2), 1);
            for r = 1 : size(this, 2)
                rec_ok(r) = any(~isnan(this(:,r).out.getZtd));
            end
            sta_list = this(:, rec_ok);

            if nargin < 3
                new_fig = true;
            end

            switch lower(par_name)
                case 'ztd'
                    [tropo] = sta_list(1).out.getZtd();
                case 'zwd'
                    [tropo] = sta_list(1).out.getZwd();
                case 'pwv'
                    [tropo] = sta_list(1).out.getPwv();
                case 'zhd'
                    [tropo] = sta_list(1).out.getAprZhd();
            end

            if ~iscell(tropo)
                tropo = {tropo};
            end
            if isempty(tropo)
                sta_list(1).out.log.addWarning([par_name ' and slants have not been computed']);
            else
                if new_fig
                    f = figure; f.Name = sprintf('%03d: Median %s %s', f.Number, par_name, sta_list(1).out.getCC.sys_c); f.NumberTitle = 'off';
                    old_legend = {};
                else
                    l = legend;
                    old_legend = get(l,'String');
                end
                for r = 1 : numel(sta_list)
                    rec = sta_list(~sta_list(r).isEmpty, r);
                    if ~isempty(rec)
                        switch lower(par_name)
                            case 'ztd'
                                [tropo] = rec.out.getZtd();
                            case 'zwd'
                                [tropo] = rec.out.getZwd();
                            case 'pwv'
                                [tropo] = rec.out.getPwv();
                            case 'zhd'
                                [tropo] = rec.out.getAprZhd();
                        end
                        [~, ~, ~, h_o] = rec(1).out.getPosGeodetic();
                        if new_fig
                            plot(h_o, zero2nan(median(tropo,'omitnan')), '.', 'MarkerSize', 25, 'LineWidth', 4, 'Color', Core_UI.getColor(r, size(sta_list, 2))); hold on;
                        else
                            plot(h_o, zero2nan(median(tropo,'omitnan')), '.', 'MarkerSize', 25, 'LineWidth', 4); hold on;
                        end
                        outm{r} = rec(1).getMarkerName();
                        h_ortho(r) = h_o;
                        med_tropo(r) = median(tropo,'omitnan');
                    else
                        h_ortho(r) = nan;
                        med_tropo(r) = nan;
                    end
                end

                h_ortho(med_tropo == 0) = nan;
                med_tropo = zero2nan(med_tropo);
                degree = 2;
                h_grid = min(noNaN(h_ortho)) :  min(10, diff(minMax(noNaN(h_ortho)))/100) : max(noNaN(h_ortho));
                h_component = Core_Utils.interp1LS(noNaN(h_ortho), noNaN(med_tropo), degree, h_grid);
                plot(h_grid, h_component, '-k', 'LineWidth', 2);

                outm = [old_legend, outm];
                [~, icons] = legend(outm, 'Location', 'NorthEastOutside', 'interpreter', 'none');
                n_entry = numel(outm);
                icons = icons(n_entry + 2 : 2 : end);

                for i = 1 : numel(icons)
                    icons(i).MarkerSize = 16;
                end

                %ylim(yl);
                %xlim(t(time_start) + [0 win_size-1] ./ 86400);
                h = ylabel([par_name ' [m]']); h.FontWeight = 'bold';
                h = xlabel('Elevation [m]'); h.FontWeight = 'bold';
                grid on;
                h = title(['Median Receiver ' par_name]); h.FontWeight = 'bold'; %h.Units = 'pixels'; h.Position(2) = h.Position(2) + 8; h.Units = 'data';
            end
        end

        function showMedianZhd(this, new_fig)
            if nargin == 1
                new_fig = true;
            end
            this.showMedianTropoPar('ZHD', new_fig)
        end

        function showMedianZwd(this, new_fig)
            if nargin == 1
                new_fig = true;
            end
            this.showMedianTropoPar('ZWD', new_fig)
        end

        function showMedianZtd(this, new_fig)
            if nargin == 1
                new_fig = true;
            end
            this.showMedianTropoPar('ZTD', new_fig)
        end

        function showMedianPwv(this, new_fig)
            if nargin == 1
                new_fig = true;
            end
            this.showMedianTropoPar('PWV', new_fig)
        end

        function showZtdSlantRes_p(this, time_start, time_stop)
            for r = 1 : size(this, 2)
                ztd = this(r).out.getZtd();
                slant_td = this(r).out.getSlantTD();
                if isempty(ztd) || ~any(slant_td(:))
                    this.log.addWarning('ZTD and slants have not been computed');
                else
                    this(r).out.showZtdSlantRes_p(time_start, time_stop)
                end
            end
        end

        function showBaselineENU(sta_list, baseline_ids, plot_relative_variation, one_plot)
            % Function to plot baseline between 2 or more stations
            %
            % INPUT:
            %   sta_list                 list of GNSS_Station objects
            %   baseline_ids/ref_id      n_baseline x 2 - couple of id in sta_list to be used
            %                            if this field is a single element interpret it as reference
            %   plot_relative_variation  show full baseline dimension / variation wrt the median value
            %   one_plot                 use subplots (E, N, U) or a single plot
            %
            % SYNTAX
            %   showBaselineENU(sta_list, <baseline_ids = []>, <plot_relative_variation = true>, <one_plot = false>)
            %   showBaselineENU(sta_list, <ref_id>, <plot_relative_variation = true>, <one_plot = false>)
            

            if (nargin < 4) || isempty(one_plot)
                one_plot = false;
            end
            if (nargin < 3) || isempty(plot_relative_variation)
                plot_relative_variation = true;
            end

            if nargin < 2 || isempty(baseline_ids)
                % remove empty receivers
                sta_list = sta_list(~sta_list.isEmpty_mr);

                n_rec = numel(sta_list);
                baseline_ids = GNSS_Station.getBaselineId(n_rec);
            end

            if numel(baseline_ids) == 1
                n_rec = numel(sta_list);
                ref_rec = setdiff((1 : n_rec)', baseline_ids);
                baseline_ids = [baseline_ids * ones(n_rec - 1, 1), ref_rec];
            end
            
            for b = 1 : size(baseline_ids, 1)
                rec = sta_list(baseline_ids(b, :));
                if ~isempty(rec(1)) && ~isempty(rec(2))
                    [enu, time] = rec.getPosENU_mr();
                    if size(enu, 1) > 1
                        rec(1).log.addMessage('Plotting positions');

                        % prepare data
                        baseline = diff(enu, 1, 3);
                        if plot_relative_variation
                            baseline = bsxfun(@minus, baseline, median(baseline, 'omitnan')) * 1e3;
                        end
                        t = time.getMatlabTime();

                        f = figure; f.Name = sprintf('%03d: BSL ENU %s - %s', f.Number, rec(1).getMarkerName4Ch, rec(2).getMarkerName4Ch); f.NumberTitle = 'off';
                        color_order = handle(gca).ColorOrder;

                        if ~one_plot, subplot(3,1,1); end
                        plot(t, baseline(:, 1), '.-', 'MarkerSize', 15, 'LineWidth', 2, 'Color', color_order(1,:)); hold on;
                        ax(3) = gca();
                        if (t(end) > t(1))
                            xlim([t(1) t(end)]);
                        end
                        setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
                        if plot_relative_variation
                            h = ylabel('East [mm]'); h.FontWeight = 'bold';
                        else
                            h = ylabel('East [m]'); h.FontWeight = 'bold';
                        end
                        grid minor;
                        h = title(sprintf('Baseline %s - %s \t\tstd E %.2f - N %.2f - U%.2f -', rec(1).getMarkerName4Ch, rec(2).getMarkerName4Ch, std(baseline, 'omitnan')), 'interpreter', 'none'); h.FontWeight = 'bold'; %h.Units = 'pixels'; h.Position(2) = h.Position(2) + 8; h.Units = 'data';

                        if ~one_plot, subplot(3,1,2); end
                        plot(t, baseline(:, 2), '.-', 'MarkerSize', 15, 'LineWidth', 2, 'Color', color_order(2,:));
                        ax(2) = gca();
                        if (t(end) > t(1))
                            xlim([t(1) t(end)]);
                        end
                        setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
                        if plot_relative_variation
                            h = ylabel('North [mm]'); h.FontWeight = 'bold';
                        else
                            h = ylabel('North [m]'); h.FontWeight = 'bold';
                        end

                        grid minor;
                        if ~one_plot, subplot(3,1,3); end
                        plot(t, baseline(:,3), '.-', 'MarkerSize', 15, 'LineWidth', 2, 'Color', color_order(3,:));
                        ax(1) = gca();
                        if (t(end) > t(1))
                            xlim([t(1) t(end)]);
                        end
                        setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
                        if plot_relative_variation
                            h = ylabel('Up [mm]'); h.FontWeight = 'bold';
                        else
                            h = ylabel('Up [m]'); h.FontWeight = 'bold';
                        end

                        grid minor;
                        if one_plot
                            if plot_relative_variation
                                h = ylabel('ENU [mm]'); h.FontWeight = 'bold';
                            else
                                h = ylabel('ENU [m]'); h.FontWeight = 'bold';
                            end
                            legend({'East', 'North', 'Up'}, 'Location', 'NorthEastOutside', 'interpreter', 'none');

                        else
                            linkaxes(ax, 'x');
                        end
                        grid on;

                    else
                        rec(1).log.addMessage('Plotting a single point static position is not yet supported');
                    end
                end

            end
        end
        
        function [m_diff, s_diff] = showRadiosondeValidation(sta_list, rds_list)
            % Compute and show comparison with radiosondes from weather.uwyo.edu
            % given region list, and station id (as cell arrays)
            %
            % INPUT
            %   sta_list        list of gnss receivers
            %   rds_list        cell array of string containing the radiosonde ID as used at "http://weather.uwyo.edu/upperair/sounding.html"
            %
            % OUTPUT
            %   m_diff          mean of the ZTD differences
            %   s_diff          std of the ZTD differences
            %
            % SYNTAX
            %  [m_diff, s_diff] = sta_list.showRadiosondeValidation(station_list);
            %
            % EXAMPLE
            %  % testing geonet full network
            %  [m_diff, s_diff] = sta_list.showRadiosondeValidation(Radiosonde.JAPAN_STATION);
            %
            % SEE ALSE
            %   Radiosonde GNSS_Station.getRadiosondeValidation
            
            [m_diff, s_diff] = sta_list.getRadiosondeValidation(rds_list, true);            
        end
        
        function showIGSComparison(sta_list)
            % Function to show the comparison between results stored in the
            % rec and official igs solutions
            %
            % SYNTAX
            %   sta_list.showIGSComparison()
            n_rec = length(sta_list);
            east_stat = nan(n_rec,2);
            north_stat = nan(n_rec,2);
            up_stat = nan(n_rec,2);
            ztd_stat = nan(n_rec,2);
            gn_stat = nan(n_rec,2);
            ge_stat = nan(n_rec,2);
            sta_names = {};
            for r = 1:n_rec
                if ~sta_list(r).out.isEmpty
                    xyz_diff = sta_list(r).out.xyz - sta_list(r).out.getIGSXYZ;
                    enu_diff = Coordinates.cart2local(sta_list(r).out.getMedianPosXYZ,xyz_diff);
                    sensor= enu_diff - repmat(median(enu_diff,'omitnan'),size(enu_diff,1),1);
                    out_idx = sum((abs(sensor) > 0.05),2) >0;
                    enu_diff(out_idx,:) =[];
                    east_stat(r,:) = [mean(enu_diff(:,1),'omitnan'),perc(abs(enu_diff(:,1) - mean(enu_diff(:,1),'omitnan')),0.95)]*1e3;
                    north_stat(r,:) = [mean(enu_diff(:,2),'omitnan'),perc(abs(enu_diff(:,2) - mean(enu_diff(:,2),'omitnan')),0.95)]*1e3;
                    up_stat(r,:) = [mean(enu_diff(:,3),'omitnan'),perc(abs(enu_diff(:,3) - mean(enu_diff(:,3),'omitnan')),0.95)]*1e3;
                    [ztd_diff, gn_diff, ge_diff] =  sta_list(r).out.getIGSTropo('value');
                    ztd_diff = ztd_diff - sta_list(r).out.ztd;
                    gn_diff = gn_diff - sta_list(r).out.tgn;
                    ge_diff = ge_diff - sta_list(r).out.tge;
                    out_idx = abs(ztd_diff) >0.05 | abs(gn_diff) >0.01 | abs(ge_diff) > 0.01;
                    ztd_diff(out_idx) = [];
                    gn_diff(out_idx) = [];
                    ge_diff(out_idx) = [];
                    ztd_stat(r,:) = [mean(ztd_diff,'omitnan'),perc(abs(ztd_diff - mean(ztd_diff,'omitnan')),0.95)]*1e3;
                    gn_stat(r,:) = [mean(gn_diff,'omitnan'),perc(abs(gn_diff - mean(gn_diff,'omitnan')),0.95)]*1e3;
                    ge_stat(r,:) = [mean(ge_diff,'omitnan'),perc(abs(ge_diff - mean(ge_diff,'omitnan')),0.95)]*1e3;
                end
                sta_names{end+1} = lower(sta_list(r).getMarkerName4Ch);
                r
            end
            % sort by bet on the east axis
            %[~,idx] = sort(abs(east_stat(:,1)));
            [~, idx] = sort(east_stat(:,1).^2 + north_stat(:,1).^2 + 0*up_stat(:,1).^2);
            east_stat = east_stat(idx,:);
            north_stat = north_stat(idx,:);
            up_stat = up_stat(idx,:);
            ztd_stat = ztd_stat(idx,:);
            gn_stat = gn_stat(idx,:);
            ge_stat = ge_stat(idx,:);
            sta_names = sta_names(idx);
            
            figure;
            subplot(6,1,1)
            errorbar(1:n_rec,east_stat(:,1),east_stat(:,2),'.','MarkerSize',15,'LineWidth',1,'Color',Core_UI.getColor(1,6))
            ylabel('[mm]')
            title('East')
            ax = gca;
            ax.YGrid = 'on';
            ax.GridLineStyle = '-';
            set(gca, 'YTick', [-30 -10 0 10 30])
            ylim([-30 30])
            set(gca, 'XTickLabels', {})    
            set(gca,'fontweight','bold','fontsize',12)
            setAllLinesWidth(1.3)
            
            subplot(6,1,2)
            errorbar(1:n_rec,north_stat(:,1),north_stat(:,2),'.','MarkerSize',15,'LineWidth',1,'Color',Core_UI.getColor(2,6))
            ax = gca;
            ax.YGrid = 'on';
            ax.GridLineStyle = '-';
            set(gca, 'YTick', [-30 -10 0 10 30])
            ylim([-30 30])
            set(gca, 'XTickLabels', {})
            ylabel('[mm]')
            set(gca,'fontweight','bold','fontsize',12)
            title('North')
            
            subplot(6,1,3)
            errorbar(1:n_rec,up_stat(:,1),up_stat(:,2),'.','MarkerSize',15,'LineWidth',1,'Color',Core_UI.getColor(3,6))
            ax = gca;
            ax.YGrid = 'on';
            ax.GridLineStyle = '-';
            ylim([-50 50]);
            set(gca, 'YTick', [-50 -20 0 20 50])
            %set(gca, 'XTick', [1:28])
            set(gca, 'XTickLabels', {})
            ylabel('[mm]')
            title('Up')
            set(gca, 'XTickLabelRotation', 45)
            set(gca,'fontweight','bold','fontsize',12)

            subplot(6,1,4)
            errorbar(1:n_rec,ztd_stat(:,1),ztd_stat(:,2),'.','MarkerSize',15,'LineWidth',1,'Color',Core_UI.getColor(4,6))
            ylabel('[mm]')
            set(gca, 'XTickLabels', {})
            ylim([-25 25])
                        ax = gca;

            ax.YGrid = 'on';
            ax.GridLineStyle = '-';
            set(gca, 'YTick', [-25 -10 0 10 25])
            set(gca,'fontweight','bold','fontsize',12)
            title('ZTD')
            
            subplot(6,1,5)
            errorbar(1:n_rec,gn_stat(:,1),gn_stat(:,2),'.','MarkerSize',15,'LineWidth',1,'Color',Core_UI.getColor(5,6))
            ylabel('[mm]')
            set(gca, 'XTickLabels', {})
            ylim([-4 4])
                        ax = gca;

            ax.YGrid = 'on';
            ax.GridLineStyle = '-';
            set(gca, 'YTick', [-4 -1 0 1 4])
            set(gca,'fontweight','bold','fontsize',12)
            title('North gradient')
            
            subplot(6,1,6)
            errorbar(1:n_rec,ge_stat(:,1),ge_stat(:,2),'.','MarkerSize',15,'LineWidth',1,'Color',Core_UI.getColor(6,6))
            ylabel('[mm]')
            ylim([-4 4])
            ax = gca;

            ax.YGrid = 'on';
            ax.GridLineStyle = '-';
            set(gca, 'YTick', [-4 -1 0 1 4])
            set(gca, 'XTickLabels', {})
            title('East gradient')
            set(gca, 'XTick', [1:28])
            set(gca, 'XTickLabels', sta_names)
            set(gca, 'XTickLabelRotation', 45)
            set(gca,'fontweight','bold','fontsize',12)
            
            
        end
        
        function showBaselinePlanarUp(sta_list, baseline_ids, plot_relative_variation)
            % Function to plot baseline between 2 or more stations
            %
            % INPUT:
            %   sta_list                 list of GNSS_Station objects
            %   baseline_ids/ref_id      n_baseline x 2 - couple of id in sta_list to be used
            %                            if this field is a single element interpret it as reference
            %   plot_relative_variation  show full baseline dimension / variation wrt the median value
            %
            % SYNTAX
            %   sta_list.showBaselinePlanarUp(<baseline_ids = []>, <plot_relative_variation = true>)
            %   sta_list.showBaselinePlanarUp(<ref_id>, <plot_relative_variation = true>)
            
            if (nargin < 3) || isempty(plot_relative_variation)
                plot_relative_variation = true;
            end

            if nargin < 2 || isempty(baseline_ids)
                % remove empty receivers
                sta_list = sta_list(~sta_list.isEmpty_mr);

                n_rec = numel(sta_list);
                baseline_ids = GNSS_Station.getBaselineId(n_rec);
            end

            if numel(baseline_ids) == 1
                n_rec = numel(sta_list);
                ref_rec = setdiff((1 : n_rec)', baseline_ids);
                baseline_ids = [baseline_ids * ones(n_rec - 1, 1), ref_rec];
            end
            
            for b = 1 : size(baseline_ids, 1)
                rec = sta_list(baseline_ids(b, :));
                if ~isempty(rec(1)) && ~isempty(rec(2))
                    [enu, time] = rec.getPosENU_mr();
                    if size(enu, 1) > 1
                        rec(1).log.addMessage('Plotting positions');

                        % prepare data
                        baseline = diff(enu, 1, 3);
                        if plot_relative_variation
                            baseline = bsxfun(@minus, baseline, median(baseline, 'omitnan')) * 1e3;
                        end
                        t = time.getMatlabTime();

                        f = figure; f.Name = sprintf('%03d: BSL ENU %s - %s', f.Number, rec(1).getMarkerName4Ch, rec(2).getMarkerName4Ch); f.NumberTitle = 'off';
                        color_order = handle(gca).ColorOrder;

                        subplot(3,1,1:2)
                        
                        % plot circles
                        
                        %plot parallel
                        max_e = ceil(max(abs(minMax(baseline(:, 1))))/5) * 5;
                        max_n = ceil(max(abs(minMax(baseline(:, 1))))/5) * 5;
                        max_r = ceil(sqrt(max_e^2 + max_n^2) / 5) * 5;
                        
                        % Plot circles of precision
                        az_l = 0 : pi/200: 2*pi;
                        % dashed
                        id_dashed = serialize(bsxfun(@plus, repmat((0:20:395)',1,5), (1:5)));
                        az_l(id_dashed) = nan;
                        decl_s = ((10 : 10 : max_r));
                        for d = decl_s
                            x = cos(az_l).*d;
                            y = sin(az_l).*d;
                            plot(x,y,'color',[0.6 0.6 0.6], 'LineWidth', 2); hold on;
                            x = cos(az_l).*(d-5);
                            y = sin(az_l).*(d-5);
                            plot(x,y,'color',[0.75 0.75 0.75], 'LineWidth', 2); hold on;
                        end
                        
                        plot(baseline(:, 2), baseline(:, 1), 'o', 'MarkerSize', 4, 'LineWidth', 2, 'Color', color_order(1,:)); hold on;
                        %scatter(baseline(:, 2), baseline(:, 1), 20, t, 'filled'); hold on; colormap(Core_UI.getColor(1:numel(t), numel(t)));

                        axis equal;
                        if plot_relative_variation
                            h = ylabel('East [mm]'); h.FontWeight = 'bold';
                            h = xlabel('North [mm]'); h.FontWeight = 'bold';
                            ylim(max_r * [-1 1]);
                            xlim(max_r * [-1 1]);
                        else
                            h = ylabel('East [m]'); h.FontWeight = 'bold';
                            h = ylabel('North [m]'); h.FontWeight = 'bold';
                        end
                        grid on;
                        h = title(sprintf('Baseline %s - %s \t\tstd E %.2f - N %.2f - U%.2f -', rec(1).getMarkerName4Ch, rec(2).getMarkerName4Ch, std(baseline, 'omitnan')), 'interpreter', 'none'); h.FontWeight = 'bold'; %h.Units = 'pixels'; h.Position(2) = h.Position(2) + 8; h.Units = 'data';

                        subplot(3,1,3);
                        plot(t, baseline(:,3), '.-', 'MarkerSize', 15, 'LineWidth', 2, 'Color', color_order(3,:));
                        ax(1) = gca();
                        if (t(end) > t(1))
                            xlim([t(1) t(end)]);
                        end
                        setTimeTicks(4,'dd/mm/yyyy HH:MMPM');
                        if plot_relative_variation
                            h = ylabel('Up [mm]'); h.FontWeight = 'bold';
                        else
                            h = ylabel('Up [m]'); h.FontWeight = 'bold';
                        end

                        grid minor;
                    else
                        rec(1).log.addMessage('Plotting a single point static position is not yet supported');
                    end
                end
            end
        end
    end
end
