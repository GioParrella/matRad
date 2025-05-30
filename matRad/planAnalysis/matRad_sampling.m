function [caSampRes, mSampDose, pln, resultGUInomScen]  = matRad_sampling(ct,stf,cst,pln,w,structSel,multScen)
% matRad_randomSampling enables sampling multiple treatment scenarios
%
% call
%   [cst,pln] = matRad_setPlanUncertainties(ct,cst,pln)
%
% input
%   ct:         ct cube
%   stf:        matRad steering information struct
%   pln:        matRad plan meta information struct
%   cst:        matRad cst struct
%   w:          optional (if no weights available in stf): bixel weight
%               vector
% output
%   caSampRes:         cell array of sampling results depicting plan parameter
%   mSampDose:         matrix holding the sampled doses, each row corresponds to
%                      one dose sample
%   pln:               matRad pln struct containing sampling information
%   resultGUInomScen:  resultGUI struct of the nominal scenario
%
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Copyright 2017 the matRad development team.
%
% This file is part of the matRad project. It is subject to the license
% terms in the LICENSE file found in the top-level directory of this
% distribution and at https://github.com/e0404/matRad/LICENSE.md. No part
% of the matRad project, including this file, may be copied, modified,
% propagated, or distributed except according to the terms contained in the
% LICENSE file.
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

matRad_cfg = MatRad_Config.instance();

% save nonSampling pln for nominal scenario calculation and add dummy fields
plnNominal = pln;
% create nominal scenario
plnNominal.multScen = matRad_multScen(ct,'nomScen');

% check for different ct scenarios
ctSamp = ct;
if ct.numOfCtScen > 1
    matRad_cfg.dispWarning('Sampling for different ct scenarios is not implemented \n');
    ctSamp.numOfCtScen = 1;
end

% either use existing multScen struct or create new one
if exist('multScen','var') && ~isempty(multScen)
    pln.multScen = multScen;
else
    % create random scenarios for sampling   
    pln.multScen = matRad_RandomScenarios(ctSamp);
    pln.multScen.nSamples = matRad_cfg.defaults.samplingScenarios;
end

matRad_cfg.dispInfo('Using %d samples in total \n',pln.multScen.totNumScen);

V = [];
% define voxels for sampling
if ~exist('structSel', 'var') || sum(size(structSel)) == 0
    V = [cst{:,4}];
else
    for i=1:size(cst,1)
        for j = 1:numel(structSel)
            if strcmp(structSel{j}, cst{i,2})
                V = [V cst{i,4}{1}];
            end
        end
    end
end

% final voxel subset for sampling
subIx = unique(vertcat(V{:}));

% disable structures for DVH plotting which are not completely in subIx
for i = 1:size(cst,1)
    if ~all(ismember(cst{i,4}{1}, subIx))
        cst{i,5}.Visible = false;
    end
end

% define variable for storing scenario doses
mSampDose   = single(zeros(numel(subIx),pln.multScen.totNumScen,1));
StorageInfo = whos('mSampDose');
matRad_cfg.dispInfo('matRad: Realizations variable will need: %f GB \n',StorageInfo.bytes/1e9);

% check if parallel toolbox is installed and license can be checked out
try
    [FlagParallToolBoxLicensed,msg]  = license('checkout','Distrib_Computing_Toolbox');
    if ~FlagParallToolBoxLicensed
        matRad_cfg.dispWarning('Could not check out parallel computing toolbox. \n');
    end
    % Create parallel pool on cluster
    p = gcp(); % If no pool, create new one.

    if isempty(p)
        matRad_cfg.dispError('matRad: Could not start valid parallel pool. Please check your parallel computing toolbox installation. \n');
    end
catch
    FlagParallToolBoxLicensed  = false;
end

%% calculate nominal scenario
nomScenTimer     = tic;
resultGUInomScen = matRad_calcDoseDirect(ct,stf,plnNominal,cst,w);
nomScenTime      = toc(nomScenTimer);
matRad_cfg.dispInfo('Finished nominal Scenario Calculation. Computation time: %f h \n',round(nomScenTime / 3600));

refVol = [2 5 50 95 98];
if isfield(resultGUInomScen,'RBExDose'), quantityVis  = 'RBExDose'; else,  quantityVis = 'physicalDose';  end

refGy = linspace(0,max(resultGUInomScen.(quantityVis)(:)),6);

resultGUInomScen.dvh = matRad_calcDVH(cst,resultGUInomScen.(quantityVis),'cum');
dvhPoints            = resultGUInomScen.dvh(1).doseGrid;
nomQi                = matRad_calcQualityIndicators(cst,pln,resultGUInomScen.(quantityVis),refGy,refVol);

resultGUInomScen.qi  = nomQi;
resultGUInomScen.cst = cst;

%% perform parallel sampling
if FlagParallToolBoxLicensed
    
    if isempty(p)
        poolSize = 1;
    else
        poolSize = p.NumWorkers;
    end

    %TODO: find a way to manage matRad_Config on a parallel pool
    logLevel = matRad_cfg.logLevel;

    % rough estimate of total computation time
    totCompTime = ceil(size(pln.multScen.scenForProb,1) / poolSize) * nomScenTime * 1.35;
    matRad_cfg.dispInfo(['Approximate Total calculation time: ', num2str(round(totCompTime / 3600)), ...
        'h. Estimated finish: ', datestr(datetime('now') + seconds(totCompTime)), '\n']);

    if exist('parfor_progress', 'file') == 2 & logLevel > 2
        FlagParforProgressDisp = true;
        parfor_progress(pln.multScen.totNumScen);  % http://de.mathworks.com/matlabcentral/fileexchange/32101-progress-monitor--progress-bar--that-works-with-parfor
    else
        matRad_cfg.dispInfo('matRad: Consider downloading parfor_progress function from the matlab central fileexchange to get feedback from parfor loop.\n');
        FlagParforProgressDisp = false;
    end

    

    parfor i = 1:pln.multScen.totNumScen
        %TODO: find a way to manage matRad_Config on a parallel pool more easily
        matRad_cfg_worker = MatRad_Config.instance();
        matRad_cfg_worker.logLevel = logLevel;

        % create nominal scenario
        plnSamp          = pln;
        plnSamp.multScen = pln.multScen.extractSingleScenario(i);

        resultSamp                 = matRad_calcDoseForward(ct,cst,stf,plnSamp,w);
        
        if isfield(resultSamp,'RBExDose'), quantityVis  = 'RBExDose'; else,  quantityVis = 'physicalDose';  end
        
        sampledDose                = resultSamp.(quantityVis)(subIx);
        mSampDose(:,i)             = single(reshape(sampledDose,[],1));
        caSampRes(i).bioModel      = pln.bioModel;
        caSampRes(i).relRangeShift = plnSamp.multScen.relRangeShift;
        caSampRes(i).absRangeShift = plnSamp.multScen.absRangeShift;
        caSampRes(i).isoShift      = plnSamp.multScen.isoShift;

        caSampRes(i).dvh = matRad_calcDVH(cst,resultSamp.(quantityVis),'cum',dvhPoints);
        caSampRes(i).qi  = matRad_calcQualityIndicators(cst,pln,resultSamp.(quantityVis),refGy,refVol);

        if FlagParforProgressDisp & logLevel > 2
            parfor_progress;
        end
    end

    if FlagParforProgressDisp & logLevel > 2
        parfor_progress(0);
    end

else
    %% perform seriel sampling
    % rough estimate of total computation time
    totCompTime = size(pln.multScen.scenForProb,1) * nomScenTime * 1.1;
    try
        matRad_cfg.dispInfo(['Approximate Total calculation time: ', num2str(round(totCompTime / 3600)), ...
            'h. Estimated finish: ', datestr(datetime('now') + seconds(totCompTime)), '\n']);
    catch
        matRad_cfg.dispInfo(['Approximate Total calculation time: ', num2str(round(totCompTime / 3600)), '\n']);
    end

    for i = 1:pln.multScen.totNumScen

        % create nominal scenario
        plnSamp          = pln;
        plnSamp.multScen = pln.multScen.extractSingleScenario(i);

        resultSamp                 = matRad_calcDoseDirect(ct,stf,plnSamp,cst,w);

        if isfield(resultSamp,'RBExDose'), quantityVis  = 'RBExDose'; else,  quantityVis = 'physicalDose';  end

        sampledDose                = resultSamp.(quantityVis)(subIx);
        mSampDose(:,i)             = single(reshape(sampledDose,[],1));
        caSampRes(i).bioModel      = pln.bioModel;
        caSampRes(i).relRangeShift = plnSamp.multScen.relRangeShift;
        caSampRes(i).absRangeShift = plnSamp.multScen.absRangeShift;
        caSampRes(i).isoShift      = plnSamp.multScen.isoShift;

        caSampRes(i).dvh = matRad_calcDVH(cst,resultSamp.(quantityVis),'cum',dvhPoints);
        caSampRes(i).qi  = matRad_calcQualityIndicators(cst,pln,resultSamp.(quantityVis),refGy,refVol);

        % Show progress
        if matRad_cfg.logLevel > 2
            matRad_progress(i, pln.multScen.totNumScen);
        end
    end
end

%% add subindices
pln.subIx        = subIx;

end
