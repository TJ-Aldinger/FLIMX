classdef subjectParamMgr < paramMgr
    %=============================================================================================================
    %
    % @file     subjectParamMgr.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     July, 2015
    %
    % @section  LICENSE
    %
    % Copyright (C) 2015, Matthias Klemm. All rights reserved.
    %
    % Redistribution and use in source and binary forms, with or without modification, are permitted provided that
    % the following conditions are met:
    %     * Redistributions of source code must retain the above copyright notice, this list of conditions and the
    %       following disclaimer.
    %     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
    %       the following disclaimer in the documentation and/or other materials provided with the distribution.
    %     * Neither the name of FLIMX authors nor the names of its contributors may be used
    %       to endorse or promote products derived from this software without specific prior written permission.
    %
    % THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
    % WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
    % PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
    % INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    % PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
    % HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
    % NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    % POSSIBILITY OF SUCH DAMAGE.
    %
    %
    % @brief    A class to manage parameters, no ini-file access
    %
    properties(GetAccess = private, SetAccess = private)
        mySubject = [];
        volatilePixelParams = [];
        volatileChannelParams = cell(2,1);
    end
    
    properties (Dependent = true)
        fluoFileObj = [];
        resultObj = [];
    end
    
    methods
        function this = subjectParamMgr(hSubject,about)
            %constructor            
            this = this@paramMgr(about);
            this.mySubject = hSubject;
            %make volatile parameters struct
            this.volatilePixelParams.nModelParamsPerCh = 0;
            this.volatilePixelParams.nApproxParamsAllCh = 0;
            this.volatilePixelParams.nGFApproxParamsPerCh = 0;              
            this.volatilePixelParams.globalFitMask = []; %mask which elements in xVec are globally fitted
            this.volatilePixelParams.compatibleGPUs = []; %list of compatible GPUs
            this.volatilePixelParams.nScatter = 0;
            this.volatilePixelParams.modelParamsString = cell(0,0);
            cp.nApproxParamsPerCh = 0;
            cp.cVec = []; %constant elements of xVec
            cp.cMask = []; %mask where constant elements are located in xVec
            this.volatileChannelParams{1} = cp;
            this.volatileChannelParams{2} = cp;
        end
        
        %% input methods
        
        %% output methods
        function out = get.fluoFileObj(this)
            %get handle to measurement
            out = this.mySubject.myMeasurement;
        end
        
        function out = get.resultObj(this)
            %get handle to result
            out = this.mySubject.myResult;
        end
        
        function out = getVolatileChannelParams(this,ch)
            %return volatile parameters for channel ch
            out = [];
            if(ch == 0)
                out = this.volatileChannelParams;
            elseif(ch > 0 && ch <= length(this.volatileChannelParams))
                out = this.volatileChannelParams{ch};
            end
        end
                
        %% compute methods
        function makeVolatileParams(this)
            %update the number of fit paramters
            %check scatter light
            basicParams = this.data.basic_fit;
            %             if(basicParams.scatterEnable && ~isempty(this.FLIMXObj) && ~isempty(this.FLIMXObj.curResultObj))
            %                 %check if have the study
            %                 if(~any(strcmp(basicParams.scatterStudy,this.FLIMXObj.fdtObj.getStudyNames())) || (~isempty(this.myFluoFile) && strcmp(basicParams.scatterStudy,this.myFluoFile.studyName)))
            %                     %we don't have that scatter study or study of fluoFile is scatter study
            %                     basicParams.scatterStudy = '';
            %                 else
            %                     %we have that scatter study -> check if we have the subject
            %                     if(~any(strcmp(this.myFluoFile.datasetName,this.FLIMXObj.fdtObj.getSubjectsNames(basicParams.scatterStudy,'-'))))
            %                         %we don't have that scatter subject
            %                         basicParams.scatterStudy = '';
            %                     end
            %                 end
            %             end
            [this.volatilePixelParams, this.volatileChannelParams] = paramMgr.makeVolatileParams(basicParams,this.mySubject.nrSpectralChannels);
        end
        
    end
    
    methods(Access = protected)
        %internal methods        
        function goOn = setSection(this,sStr,new,resetResults)
            %single parameter struct            
            %update new sections
            goOn = true;
            if(strcmp('volatilePixel',sStr))
                fields = intersect(fieldnames(new),fieldnames(this.volatilePixelParams));
                tmp = this.volatilePixelParams;
                for j = 1:length(fields)
                    tmp.(fields{j}) = new.(fields{j});
                end
                this.volatilePixelParams = tmp;
%             elseif(strcmp('volatileChannel',sStr))
%                 if(ch > 1 && ch <= length(this.volatileChannelParams))
%                     tmp = this.volatileChannelParams{ch};
%                     fields = intersect(fieldnames(new),fieldnames(tmp));
%                     for j = 1:length(fields)
%                         tmp.(fields{j}) = new.(fields{j});
%                     end
%                     this.volatileChannelParams{ch} = tmp;
%                 end
            elseif(any(strcmp(sStr,fieldnames(this.data))))
                fields = intersect(fieldnames(new),fieldnames(this.data.(sStr)));
                tmp = this.data.(sStr);
                old = tmp;
                for j = 1:length(fields)
                    tmp.(fields{j}) = new.(fields{j});
                end
                this.data.(sStr) = tmp;
                %update other objects if necessary
                switch sStr
                    case 'pre_processing'
                        %possible binning change
                        if(~isempty(this.fluoFileObj))
                            %check if something has changed
                            for j = 1:length(fields)
                                if(old.(fields{j}) ~= new.(fields{j}))
                                    this.fluoFileObj.clearROIData();
                                    break
                                end
                            end                            
                        end
                    case 'basic_fit'
                        this.volatileChannelParams{1}.cVec = [];
                        this.volatileChannelParams{2}.cVec = [];
                        this.makeVolatileParams();
                        if(resetResults)
                            for ch = 1:this.fluoFileObj.nrSpectralChannels
                                this.resultObj.allocResults(ch,this.fluoFileObj.getROIYSz(),this.fluoFileObj.getROIXSz());
                            end
                        end
                    case 'init_fit'
                        if(~isempty(this.fluoFileObj) && (isfield(new,'gridSize') && new.gridSize ~= old.gridSize || isfield(new,'gridPhotons') && new.gridPhotons ~= old.gridPhotons))
                            this.fluoFileObj.clearInitData();
                            for ch = 1:this.fluoFileObj.nrSpectralChannels
                                this.resultObj.allocResults(ch,this.fluoFileObj.getROIYSz(),this.fluoFileObj.getROIXSz());
                            end
                        end
                    case 'computation'
                        %check GPU support
%                         warning('off','parallel:gpu:DeviceCapability');
%                         if(isfield(new,'useGPU') && new.useGPU && isempty(this.volatilePixelParams.compatibleGPUs) && isGpuAvailable())
%                             GPUList = [];
%                             for i = 1:gpuDeviceCount
%                                 info = gpuDevice(i);
%                                 if(info.DeviceSupported)
%                                     GPUList = [GPUList i];
%                                 end
%                             end
%                             this.volatilePixelParams.compatibleGPUs = GPUList;
%                         elseif(isfield(new,'useGPU') && ~new.useGPU)
%                             this.volatilePixelParams.compatibleGPUs = [];
%                         end
%                         warning('on','parallel:gpu:DeviceCapability');
                end
            else
                goOn = false;
                warning('paramMgr:setSection','Parameter section %s not found in config file. The section has been ignored.',sStr);
            end
        end
        
        function out = getSection(this,sStr)
            %get a section from the config file
            out = [];
            if(strcmp('volatilePixel',sStr))
                out = this.volatilePixelParams;
            elseif(strcmp('volatileChannel',sStr))
                %                 if(ch > 0 && ch <= length(this.volatileChannelParams))
                %                     out = this.volatileChannelParams{ch};
                %                 else
                %                     out = this.volatileChannelParams;
                %                 end
            else
                out = getSection@paramMgr(this,sStr);
            end
        end
        
    end
end