function obj = matRad_exportDicomRTStruct(obj)
% matRad function to export dicom RT structure set. 
% Class method of matRad_DicomExporter
% 
% call
%   matRad_DicomExporter.matRad_exportDicomRTStruct()
%          
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

matRad_cfg = MatRad_Config.instance();
matRad_cfg.dispInfo('Exporting DICOM RTStruct...\n');

if matRad_cfg.isOctave
    matRad_cfg.dispWarning('RTStruct export currently not supported by matRad running in Octave due to crashing dicomwrite! Skipping...');
    return;
end

%% Metadata
%Class UID
ClassUID = obj.rtStructClassUID; %RT Structure Set
meta.MediaStorageSOPClassUID = ClassUID;
meta.SOPClassUID             = ClassUID;
%TransferSyntaxUID = '1.2.840.10008.1.2.1'; %Explicit VR Little Endian - correct?
%meta.TransferSyntaxUID = TransferSyntaxUID; 

%Identifiers
meta.FrameOfReferenceUID        = obj.FrameOfReferenceUID;
meta.SOPInstanceUID             = dicomuid;
meta.MediaStorageSOPInstanceUID = meta.SOPInstanceUID;
meta.SeriesInstanceUID          = dicomuid;
meta.SeriesNumber               = 1;
meta.InstanceNumber             = 1;

%Remaining Meta Data
meta.Modality = 'RTSTRUCT';
meta.Manufacturer = '';
meta.ReferringPhysicianName = obj.dicomName();
meta.OperatorsName = obj.OperatorsName;
meta.StationName = '';
meta = obj.assignDefaultMetaValue(meta,'ManufacturerModelName','matRad DicomExport');

meta.PatientName = obj.PatientName;
meta.PatientID = obj.PatientID;
meta.PatientBirthDate = obj.PatientBirthDate;
meta.PatientSex = obj.PatientSex;

%Name
meta = matRad_DicomExporter.assignDefaultMetaValue(meta,'StructureSetLabel','matRad_cst');
meta = matRad_DicomExporter.assignDefaultMetaValue(meta,'StructureSetName','matRad exported cst');



%ID of the Study
meta.StudyInstanceUID = obj.StudyInstanceUID;
meta.StudyID          = obj.StudyID; 

%Dates & Times
currDate = now;
currDateStr = datestr(currDate,'yyyymmdd');
currTimeStr = datestr(currDate,'HHMMSS');
meta.InstanceCreationDate = currDateStr;
meta.InstanceCreationTime = currTimeStr;
meta.StudyDate = obj.StudyDate;
meta.StudyTime = obj.StudyTime;
meta = matRad_DicomExporter.assignDefaultMetaValue(meta,'StructureSetDate',currDateStr);
meta = matRad_DicomExporter.assignDefaultMetaValue(meta,'StructureSetTime',currTimeStr);


%Remaining stuff
meta.AccessionNumber = '';

%meta.PatientBirthDate = '';
%meta.PatientSex = 'O';
%meta.SoftwareVersion = '';

ct = obj.ct;

%Create X Y Z vectors if not present
ct = matRad_getWorldAxes(ct);



%Since we are exporting HU directly --> no rescaling in any case
meta.SliceThickness = num2str(ct.resolution.z);
meta.PixelSpacing = [ct.resolution.y; ct.resolution.x];
meta.ImageOrientationPatient = [1;0;0;0;1;0]; %lps

%meta.RescaleSlope = 1;
%meta.RescaleIntercept = 0;    

obj.cst = matRad_computeVoiContoursWrapper(obj.cst,ct);

for i = 1:size(obj.cst,1)
   
    matRad_cfg.dispInfo('Processinging VOI ''%s''...',obj.cst{i,2});
   %Select contours in axial slices
    contours        = obj.cst{i,7}{obj.exportScenario}(:,3);
    contourSliceIx  = find(~cellfun(@isempty,contours));    
    contourSlicePos = ct.z(contourSliceIx);
    contours        = contours(contourSliceIx);
        
    % consider multiple contours of the same object
    for slice = 1:numel(contours)
       
       tmpContour = [];
       lower         = 1; % lower marks the beginning of a section
       cnt           = 0;
       
       while lower-1 ~= size(contours{slice,1},2)
         
          steps = contours{slice,1}(2,lower); % number of elements of current line section
          
          tmpContour(:,lower-cnt:lower-cnt+steps-1) = contours{slice,1}(:,lower+1:lower+steps);
          
          lower = lower+steps+1;
          cnt   = cnt + 1;
       end
       
       contours{slice,1} = tmpContour;
       
    end
    
    contours = cellfun(@(c) [ct.resolution.x; ct.resolution.y].* c + [ct.x(1) - ct.resolution.x;...
                             ct.y(1) - ct.resolution.y],contours,'UniformOutput',false);
      
    
    contours = cellfun(@(c,pos) addSlicePos(c,pos),contours,num2cell(contourSlicePos)','UniformOutput',false);
    %contours = cellfun(@transpose,contours,'UniformOutput',false);
    
    %Structure Definition
    ROISequenceItem.ROINumber = i;    
    ROISequenceItem.ReferencedFrameOfReferenceUID = obj.FrameOfReferenceUID;
    ROISequenceItem.ROIName = obj.cst{i,2};
    ROISequenceItem.ROIGenerationAlgorithm = '';
    
    meta.StructureSetROISequence.(['Item_' num2str(i)]) = ROISequenceItem;
    
    %Contour Sequence
    if ~ matRad_cfg.isOctave
        ROIContourSequenceItem.ROIDisplayColor = int32(round(255 * obj.cst{i,5}.visibleColor));
    end
    
    %Now create Contour subitems
    ContourSequence = struct;
    for c = 1:numel(contours)
        ContourItem = struct;
        
        %First store Image Sequence
        currCtSliceMeta = obj.ctSliceMetas(contourSliceIx(c));
        %currCtSliceMeta = matRad_DicomExporter.assignDefaultMetaValue(currCtSliceMeta,'SOPClassUID','1.2.840.10008.5.1.4.1.1.2');
        
        %Not sure about this
        ContourItem.ContourImageSequence.Item_1.ReferencedSOPClassUID = currCtSliceMeta.SOPClassUID; %We are referencing the CT
        ContourItem.ContourImageSequence.Item_1.ReferencedSOPInstanceUID = currCtSliceMeta.SOPInstanceUID; %TODO: ID of the respective ctSlice        
        
        %Now remaing data
        ContourItem.ContourGeometricType = 'CLOSED_PLANAR';
        ContourItem.NumberOfContourPoints = size(contours{c},2);
        ContourItem.ContourData = contours{c}(:);
        
        
        %Now store Item
        ContourSequence.(['Item_' num2str(c)]) = ContourItem;
    end
    ROIContourSequenceItem.ContourSequence = ContourSequence;
    
    ROIContourSequenceItem.ReferencedROINumber = i;
    
    %Store to meta data
    meta.ROIContourSequence.(['Item_' num2str(i)]) = ROIContourSequenceItem;
    
    %RTROI Observation Sequence
    RTROIObservationsSequenceItem.ObservationNumber = i;
    RTROIObservationsSequenceItem.ReferencedROINumber = i;
    RTROIObservationsSequenceItem.ROIObservationLabel = obj.cst{i,2};
        
    
    if strcmp(obj.cst{i,3},'TARGET')
        if ~isempty(regexpi(obj.cst{i,2},['(' strjoin(obj.targetPtvDict) ')'], 'once'))
            RTROIObservationsSequenceItem.RTROIInterpretedType = 'PTV';
            matRad_cfg.dispInfo('identified target type as PTV...');
        elseif ~isempty(regexpi(obj.cst{i,2},['(' strjoin(obj.targetGtvDict) ')'], 'once'))
            RTROIObservationsSequenceItem.RTROIInterpretedType = 'GTV';
            fprintf('identified target type as GTV...');
        elseif ~isempty(regexpi(obj.cst{i,2},['(' strjoin(obj.targetCtvDict) ')'], 'once'))
            RTROIObservationsSequenceItem.RTROIInterpretedType = 'CTV';
            matRad_cfg.dispInfo('identified target type as CTV...');
        else
            RTROIObservationsSequenceItem.RTROIInterpretedType = 'CTV';
            matRad_cfg.dispInfo('Defaulting target type to CTV...');
        end
    else
        if ~isempty(regexpi(obj.cst{i,2},['(' strjoin(obj.externalContourDict) ')'], 'once'))
            matRad_cfg.dispInfo('automatically identified as External Contour...');
            RTROIObservationsSequenceItem.RTROIInterpretedType = 'EXTERNAL';
        else
            RTROIObservationsSequenceItem.RTROIInterpretedType = 'AVOIDANCE';
        end
    end
    
    RTROIObservationsSequenceItem.ROIInterpreter = obj.dicomName();

    meta.RTROIObservationsSequence.(['Item_' num2str(i)]) = RTROIObservationsSequenceItem;
    
    matRad_cfg.dispInfo('Done!\n');
    %matRad_progress(i,size(obj.cst,1));
end



for i = 1:numel(obj.ctSliceMetas)
    ImageSequenceItem.ReferencedSOPClassUID = obj.ctSliceMetas(i).SOPClassUID;
    ImageSequenceItem.ReferencedSOPInstanceUID = obj.ctSliceMetas(i).SOPInstanceUID;
    ContourImageSequence.(['Item_' num2str(i)]) = ImageSequenceItem;
end

RTReferencedSeriesSequenceItem.SeriesInstanceUID = obj.ctSliceMetas(1).SeriesInstanceUID;
RTReferencedSeriesSequenceItem.ContourImageSequence = ContourImageSequence;

%RTReferencedStudySequenceItem.ReferencedSOPClassUID = '1.2.840.10008.3.1.2.3.2'; %Apparently this class UID is deprecated in DICOM standard - what to use instead?
RTReferencedStudySequenceItem.ReferencedSOPInstanceUID = obj.StudyInstanceUID;
RTReferencedStudySequenceItem.RTReferencedSeriesSequence.Item_1 = RTReferencedSeriesSequenceItem;

meta.ReferencedFrameOfReferenceSequence.Item_1.FrameOfReferenceUID = obj.FrameOfReferenceUID;
meta.ReferencedFrameOfReferenceSequence.Item_1.RTReferencedStudySequence.Item_1 = RTReferencedStudySequenceItem;

filename = 'RTstruct.dcm';
filepath = obj.dicomDir;
filename = fullfile(filepath,filename);


if matRad_cfg.isOctave
	dicomwrite(int16(zeros(2)),filename,meta);
else
    obj.rtssExportStatus = dicomwrite([],filename,meta,'CreateMode','copy');%,'TransferSyntax',TransferSyntaxUID);    
end

%We need to get the info of the file just written because of Matlab's
%hardcoded way of generating InstanceUIDs during writing
tmpInfo = dicominfo(filename);
meta.SOPInstanceUID              = tmpInfo.SOPInstanceUID;
meta.MediaStorageSOPInstanceUID  = tmpInfo.MediaStorageSOPInstanceUID;

obj.rtssMeta = meta;
end 

function c = addSlicePos(c,slicePos)
    nPoints  = size(c,2);
    slicePos = slicePos * ones(1,nPoints);
    c(3,:)   = slicePos;
end
