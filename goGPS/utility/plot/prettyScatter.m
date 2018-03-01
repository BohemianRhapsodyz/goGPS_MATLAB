% prettyScatter
%--------------------------------------------------------------------------
%
% plot with projection an area of the world
%
% POSSIBLE SINTAXES:
%   scatterHandler = prettyScatter(dataScatter, phi, lambda);
%
%   prettyScatter(dataScatter, phi, lambda, shape);
%   prettyScatter(dataScatter, phi, lambda, projection);
%   prettyScatter(dataScatter, phi, lambda, lineCol);
%
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax);
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, shape);
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection);
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, lineCol);
%
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, shape, projection);
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, shape, lineCol);
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection, shape);
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection, lineCol);
%
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection, shape, lineCol);
%   prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, shape, projection, lineCol);
%
% EXAMPLE:
%   prettyScatter(dataScatter, phiMin, phiMax, lambdaMin, lambdaMax, 'Miller Cylindrical');
%
% INPUT:
%   dataScatter     array containing the data value (z = colour)
%   phi             array [degree]
%   lambda          array [degree]
%   phiMin          minimum latitude    [degree]
%   phiMax          maximum latitude    [degree]
%   lambdaMin       minimum longitude   [degree]
%   lambdaMax       maximum longitude   [degree]
%   projection      type of projection to be used "standard" is the default
%   shape           shapefile to load as coast (or country) contour
%                       - coast         only coasts coarse
%                       - 50m           1:50000000 scale country contours
%                       - 30m           1:30000000 scale country contours
%                       - 10m           1:10000000 scale country contours
%                       - provinces     1:10000000 scale provinces contours
%                       - ita           1:10000000 scale italian regions contours
%   lineCol         [1 1 1] array of RGB component to draw the contour lines
%
% DEFAULT VALUES:
%    projection = 'Lambert'
%
% AVAILABLE PROJECTION:
%    * Lambert
%      Stereographic
%      Orthographic
%      Azimuthal Equal-area
%      Azimuthal Equidistant
%      Gnomonic
%      Satellite
%      Albers Equal-Area Conic
%      Lambert Conformal Conic
%      Mercator
%    * Miller Cylindrical
%    * Equidistant Cylindrical (world dataScatter)
%      Oblique Mercator
%      Transverse Mercator
%      Sinusoidal
%      Gall-Peters
%      Hammer-Aitoff
%      Mollweide
%      Robinson
%    * UTM
%
% SEE ALSO:
%   dataScatterPlot, dataScatterPlot3D, scatter
%
% REQUIREMENTS:
%   M_Map: http://www.eos.ubc.ca/~rich/dataScatter.html
%   shape files with contours
%
% VERSION: 2.1
%
% CREDITS:
%   http://www.eos.ubc.ca/~rich/dataScatter.html
%
%   Andrea Gatti
%   DIIAR - Politecnico di Milano
%   2013-12-19
%

function scatterHandler = prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection, shape, lineCol)

%shape = 'coast';
%shape = '10m';
%shape = '30m';
%shape = '50m';

% lineCol = [0 0 0];

dataScatter = dataScatter(:);
phi = phi(:);
lambda = lambda(:);

limitsOk = false;

% Manage opening a new figure;
tohold = false;
if length(findall(0,'Type','figure'))>=1
    if ishold
        tohold = true;
    else
        figure;
    end
end

switch (nargin)
    case 3
        shape = 'coast';
        lineCol = [0 0 0];
        if (ischar(phi))
            projection = 'Miller Cylindrical';
            if (sum(strcmp(phi,[{'coast'}, {'ita'}, {'provinces'},{'10m'},{'30m'},{'50m'}])))
                shape = phi;
                if (ischar(lambda))
                    projection = lambda;                              % prettyScatter(dataScatter, shape, projection);
                else
                    lineCol = lambda;                                 % prettyScatter(dataScatter, shape, lineCol);
                end
            else
                projection = phi;
                if (ischar(lambda))
                    shape = lambda;                                   % prettyScatter(dataScatter, projection, shape);
                else
                    lineCol = lambda;                                 % prettyScatter(dataScatter, projection, lineCol);
                end
            end
            phiMin = 90;
            phiMax = -90;
            lambdaMin = -180;
            lambdaMax = 180;
            
            deltaPhi = (phiMax-phiMin)/size(dataScatter,1);
            deltaLambda = (lambdaMax-lambdaMin)/size(dataScatter,2);
            
            phi    = (phiMin + deltaPhi/2 : deltaPhi : phiMax - deltaPhi/2)';
            lambda = (lambdaMin + deltaLambda/2 :  deltaLambda :  lambdaMax  - deltaLambda/2)';
        else                                                              % prettyScatter(dataScatter, phi, lambda);
            projection = 'Miller Cylindrical';
            phiMin = max(phi);
            phiMax = min(phi);
            lambdaMin = min(lambda);
            lambdaMax = max(lambda);
        end
    case 4
        shape = 'coast';
        lineCol = [0 0 0];
        projection = 'Miller Cylindrical';
        if (ischar(phiMin))
            if (sum(strcmp(phiMin,[{'coast'}, {'ita'}, {'provinces'},{'10m'},{'30m'},{'50m'}])))  % prettyScatter(dataScatter, phi, lambda, shape);
                shape = phiMin;
            else                                                          % prettyScatter(dataScatter, phi, lambda, projection);
                projection = phiMin;
            end
        elseif (length(phiMin) == 3)                                      % prettyScatter(dataScatter, phi, lambda, lineCol);
            lineCol = phiMin;
        end
        
        phiMin = max(phi);
        phiMax = min(phi);
        lambdaMin = min(lambda);
        lambdaMax = max(lambda);
    case 5
        shape = 'coast';
        lineCol = [0 0 0];
        projection = 'Miller Cylindrical';
        if (ischar(phiMin))
            if (sum(strcmp(phiMin,[{'coast'}, {'ita'}, {'provinces'},{'10m'},{'30m'},{'50m'}])))
                shape = phiMin;
                if (ischar(phiMax))
                    projection = phiMax;                                  % prettyScatter(dataScatter, phiMin, phiMax, shape, projection);
                else
                    lineCol = phiMax;                                     % prettyScatter(dataScatter, phiMin, phiMax, shape, lineCol);
                end
            else
                projection = phiMin;
                if (ischar(phiMax))
                    shape = phiMax;                                       % prettyScatter(dataScatter, phiMin, phiMax, projection, shape);
                else
                    lineCol = phiMax;                                     % prettyScatter(dataScatter, phiMin, phiMax, projection, lineCol);
                end
            end
            phiMin = max(phi);
            phiMax = min(phi);
            lambdaMin = min(lambda);
            lambdaMax = max(lambda);
        else                                                             %  prettyScatter(dataScatter, phiMin, phiMax, lambdaMin, lambdaMax);
            limitsOk = true;
            lambdaMin = phiMin;
            lambdaMax = phiMax;
            phiMin = phi;
            phiMax = lambda;
            
            if (phiMin < phiMax)
                tmp = phiMin;
                phiMin = phiMax;
                phiMax = tmp;
            end
            
            deltaPhi = (phiMax-phiMin)/size(dataScatter,1);
            deltaLambda = (lambdaMax-lambdaMin)/size(dataScatter,2);
            
            phi    = (phiMin + deltaPhi/2 : deltaPhi : phiMax - deltaPhi/2)';
            lambda = (lambdaMin + deltaLambda/2 :  deltaLambda :  lambdaMax  - deltaLambda/2)';
        end
    case 6
        shape = 'coast';
        lineCol = [0 0 0];
        limitsOk = true;
        projection = 'Lambert';        
        if (ischar(lambdaMin))
            if (sum(strcmp(lambdaMin,[{'coast'}, {'ita'}, {'provinces'},{'10m'},{'30m'},{'50m'}])))
                shape = lambdaMin;                                        % prettyScatter(dataScatter, phiMin, phiMax, lambdaMin, lambdaMax, shape);
            else
                projection = lambdaMin;
            end
        elseif (length(lambdaMin) == 3)
            lineCol = lambdaMin;                                          % prettyScatter(dataScatter, phiMin, phiMax, lambdaMin, lambdaMax, lineCol);
        end
        
        lambdaMax = phiMax;
        lambdaMin = phiMin;
        phiMin = phi;
        phiMax = lambda;
        
        if (phiMin < phiMax)
            tmp = phiMin;
            phiMin = phiMax;
            phiMax = tmp;
        end
        
        deltaPhi = (phiMax-phiMin)/size(dataScatter,1);
        deltaLambda = (lambdaMax-lambdaMin)/size(dataScatter,2);
        
        phi    = (phiMin + deltaPhi/2 : deltaPhi : phiMax - deltaPhi/2)';
        lambda = (lambdaMin + deltaLambda/2 :  deltaLambda :  lambdaMax  - deltaLambda/2)';
    case 7
        shape = 'coast';
        lineCol = [0 0 0];
        limitsOk = true;
        projection = 'Lambert';
        if (ischar(lambdaMin))
            if (sum(strcmp(lambdaMin,[{'coast'}, {'ita'}, {'provinces'},{'10m'},{'30m'},{'50m'}])))
                shape = lambdaMin;
                if (ischar(lambdaMax))
                    projection = lambdaMax;                               % prettyScatter(dataScatter, phiMin, phiMax, lambdaMin, lambdaMax, shape, projection);
                else
                    lineCol = lambdaMax;                                  % prettyScatter(dataScatter, phiMin, phiMax, lambdaMin, lambdaMax, shape, lineCol);
                end
            else
                projection = lambdaMin;
                if (ischar(lambdaMax))
                    shape = lambdaMax;                                    % prettyScatter(dataScatter, phiMin, phiMax, lambdaMin, lambdaMax, projection, shape);
                else
                    lineCol = lambdaMax;                                  % prettyScatter(dataScatter, phiMin, phiMax, lambdaMin, lambdaMax, projection, lineCol);
                end
            end
            
            lambdaMin = phiMin;
            lambdaMax = phiMax;
            phiMin = phi;
            phiMax = lambda;
            
            if (phiMin < phiMax)
                tmp = phiMin;
                phiMin = phiMax;
                phiMax = tmp;
            end
            
            deltaPhi = (phiMax-phiMin)/size(dataScatter,1);
            deltaLambda = (lambdaMax-lambdaMin)/size(dataScatter,2);
            
            phi    = (phiMin + deltaPhi/2 : deltaPhi : phiMax - deltaPhi/2)';
            lambda = (lambdaMin + deltaLambda/2 :  deltaLambda :  lambdaMax  - deltaLambda/2)';
        else
            projection = 'lambert';                                       % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax);
        end
    case 8
        shape = 'coast';
        lineCol = [0 0 0];
        limitsOk = true;
        if (ischar(projection))
            if (sum(strcmp(projection,[{'coast'}, {'ita'}, {'provinces'},{'10m'},{'30m'},{'50m'}])))
                shape = projection;                                       % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, shape);
                projection = 'Lambert';
            else
                % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection);
            end
        elseif (length(projection) == 3)
            lineCol = projection;                                         % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, lineCol);
            projection = 'Lambert';
        end
    case 9
        lineCol = [0 0 0];
        limitsOk = true;
        if (ischar(projection))
            if (sum(strcmp(projection,[{'coast'}, {'ita'}, {'provinces'},{'10m'},{'30m'},{'50m'}])))
                tmp = shape;
                shape = projection;
                if (ischar(tmp))
                    projection = tmp;                                     % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, shape, projection);
                else
                    lineCol = tmp;                                        % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, shape, lineCol);
                    projection = 'UTM';
                end
            else
                if (ischar(shape))
                    % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection, shape);
                else
                    lineCol = shape;                                      % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection, lineCol);
                    shape = 'coast';
                end
            end
        end
    case 10                                                               % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, projection, shape, lineCol)
        limitsOk = true;
        if (sum(strcmp(projection,[{'coast'}, {'ita'}, {'provinces'},{'10m'},{'30m'},{'50m'}])))   % prettyScatter(dataScatter, phi, lambda, phiMin, phiMax, lambdaMin, lambdaMax, shape, projection, lineCol)
            tmp = shape;
            shape = projection;
            projection = tmp;
        end
end

if (phiMin < phiMax)
    tmp = phiMin;
    phiMin = phiMax;
    phiMax = tmp;
end

lambdaTmp = sort(lambda);
[val, idMax] = max(diff(lambdaTmp));
if (sum(diff(lambdaTmp) == val) == 1) && val > 10
    lambdaTmp(1:idMax) = lambdaTmp(1:idMax)+360;
    if ~limitsOk
        lambdaMax = lambdaTmp(idMax);
        lambdaMin = lambdaTmp(idMax+1);    
    end
end

if(lambdaMax<lambdaMin)
    lambdaMax = lambdaMax+360;
end

if (~limitsOk)
    lambdaMin = lambdaMin-3;
    lambdaMax = lambdaMax+3;
    phiMin = min(phiMin+3,90);
    phiMax = max(phiMax-3,-90);
end
    
% setup the projection
if ~tohold
    if (strcmpi(projection,{'lambert'}) && abs(phiMax==-phiMin))
        projection='Miller Cylindrical';
    end
    
    if (sum(strcmpi(projection,[{'lambert'},{'UTM'},{'Sinusoidal'},{'Transverse Mercator'},{'Oblique Mercator'},{'Miller Cylindrical'}])))
        m_proj(projection,'long',[lambdaMin lambdaMax],'lat',[phiMax phiMin]);
    else
        m_proj(projection);
    end
    
    % Printing projection
    fprintf('Using projection: %s\n', projection);
    
    if sum(diff(lambda)<-200)
        lambda(lambda<0)=lambda(lambda<0)+360;
    end
    % plot the dataScatter
    m_pcolor([lambdaMin lambdaMax],[phiMin phiMax], nan(2));
    % set the light
    shading flat;    
end

ids = (lambda<lambdaMin) & (lambda < 0);
lambda(ids) = lambda(ids)+360;

ids = (lambda>lambdaMax);
lambda(ids) = lambda(ids)-360;

hold on;
[xlocal,ylocal] = m_ll2xy(lambda(:),phi(:));
scatterHandler = scatter(xlocal,ylocal,30,dataScatter,'filled'); % <========================= SCATTER function is here

if ~tohold
    % read shapefile
    if (~strcmp(shape,'coast'))
        if (strcmp(shape,'ita'))
            M = m_shaperead('ita_regn');
        elseif (strcmp(shape,'provinces'))
            M = m_shaperead('ne_10m_admin_1_states_provinces');
        elseif (strcmp(shape,'10m'))
            M = m_shaperead('countries_10m');
        elseif (strcmp(shape,'30m'))
            M = m_shaperead('countries_30m');
        else
            M = m_shaperead('countries_50m');
        end
        [xMin,yMin] = m_ll2xy(lambdaMin,phiMin);
        [xMax,yMax] = m_ll2xy(lambdaMax,phiMax);
        for k=1:length(M.ncst)
            lamC = M.ncst{k}(:,1);
            ids = lamC < lambdaMin;
            lamC(ids) = lamC(ids) + 360;
            phiC = M.ncst{k}(:,2);
            [x,y] = m_ll2xy(lamC,phiC);
            if sum(~isnan(x))>1
                x(find(abs(diff(x)) >= abs(xMax-xMin) * 0.70)+1) = nan; % Remove lines that occupy more than the 90% of the plot
                line(x,y,'color', lineCol);
            end
        end
    else
        m_coast('line','color', lineCol);
    end
end
m_grid('box','fancy','tickdir','in');
colorbar;

if tohold
    hold on;
else
    hold off;
end
