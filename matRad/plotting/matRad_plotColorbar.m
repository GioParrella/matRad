function cBarHandle = matRad_plotColorbar(axesHandle,cMap,window,varargin)
% matRad function wrapper for plotting the colorbar 
% This is necessary since the rgb colors are manually mapped within the ct 
% and the dose plotting, and MATLAB attaches colorbars to axes.
%
% call
%   cBarHandle = matRad_plotColorbar(axesHandle,cMap,window,varargin)
%
% input
%   axesHandle  handle to axes the colorbar will be attached to
%   cMap        corresponding colormap
%   window      colormap window (corresponds to clim)
%   varargin    additional key-value pairs that will be forwarded to the
%               MATLAB colorbar(__) call
%
% output
%   cBarHandle  handle of the colorbar object
%
% References
%   -
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Copyright 2015 the matRad development team. 
% 
% This file is part of the matRad project. It is subject to the license 
% terms in the LICENSE file found in the top-level directory of this 
% distribution and at https://github.com/e0404/matRad/LICENSE.md. No part 
% of the matRad project, including this file, may be copied, modified, 
% propagated, or distributed except according to the terms contained in the 
% LICENSE file.
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

colormap(axesHandle,cMap);
caxis(axesHandle,window);
%sanity check to avoid a crash
% if window(1) < window(2)
%     
% else
% 
%     matRad_cfg = MatRad_Config.instance();
%     matRad_cfg.dispWarning('Unsuitable display window [%d,%d] for color axis!',window(1),window(2));
% end 

matRad_cfg = MatRad_Config.instance();

if matRad_cfg.isMatlab && str2double(matRad_cfg.envVersion)<8.5
    cBarHandle = colorbar('peer',axesHandle,varargin{:});
else
    cBarHandle = colorbar(axesHandle,varargin{:});
end

