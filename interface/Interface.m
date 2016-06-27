function varargout = Interface(varargin)
% INTERFACE MATLAB code for Interface.fig
%      INTERFACE, by itself, creates a new INTERFACE or raises the existing
%      singleton*.
%
%      H = INTERFACE returns the handle to a new INTERFACE or the handle to
%      the existing singleton*.
%
%      INTERFACE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in INTERFACE.M with the given input arguments.
%
%      INTERFACE('Property','Value',...) creates a new INTERFACE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Interface_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Interface_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Interface

% Last Modified by GUIDE v2.5 23-Apr-2014 19:19:24

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Interface_OpeningFcn, ...
                   'gui_OutputFcn',  @Interface_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Interface is made visible.
function Interface_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Interface (see VARARGIN)

% Choose default command line output for Interface
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Interface wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = Interface_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%% Read image into matlab

% Reading the value from the text
filename = get(handles.edit1,'string');
% Adding the extention
filename = strcat(filename, '.dng');

warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
t = Tiff(filename,'r');
offsets = getTag(t,'SubIFD');
setSubDirectory(t,offsets(1));
raw = read(t); % Create variable ’raw’, the Bayer CFA data
close(t);
meta_info = imfinfo(filename);
% Crop to only valid pixels
x_origin = meta_info.SubIFDs{1}.ActiveArea(2)+1; % +1 due to MATLAB indexing
width = meta_info.SubIFDs{1}.DefaultCropSize(1);
y_origin = meta_info.SubIFDs{1}.ActiveArea(1)+1;
height = meta_info.SubIFDs{1}.DefaultCropSize(2);
raw = double(raw(y_origin:y_origin+height-1,x_origin:x_origin+width-1));

%% Linearize
black = meta_info.SubIFDs{1}.BlackLevel(1);
saturation = meta_info.SubIFDs{1}.WhiteLevel;
lin_bayer = (raw-black)/(saturation-black);
lin_bayer = max(0,min(lin_bayer,1));

%% White Balance
wb_multipliers = (meta_info.AsShotNeutral).^-1;
wb_multipliers = wb_multipliers/wb_multipliers(2);
mask=wbmask(size(lin_bayer,1),size(lin_bayer,2),wb_multipliers(1),wb_multipliers(3));
balanced_bayer = lin_bayer .* mask;

%% Demosaic
% This makes use of a MATLAB built in demosaic function
temp = uint16(balanced_bayer/max(balanced_bayer(:))*2^16);
lin_rgb = double(demosaic(temp,'rggb'))/2^16;

%% Convert Color Space
% Makes color more true and displayable
xyz2cam = [meta_info.ColorMatrix2(1) meta_info.ColorMatrix2(2) meta_info.ColorMatrix2(3);
           meta_info.ColorMatrix2(4) meta_info.ColorMatrix2(5) meta_info.ColorMatrix2(6);
           meta_info.ColorMatrix2(7) meta_info.ColorMatrix2(8) meta_info.ColorMatrix2(9)]; % make matrix

rgb2xyz = [0.4124564 0.3575761 0.1804375; 
           0.2126729 0.7151522 0.0721750; 
           0.0193339 0.1191920 0.9503041];

rgb2cam = xyz2cam * rgb2xyz; 
rgb2cam = rgb2cam ./ repmat(sum(rgb2cam,2),1,3); % Normalize rows to 1
cam2rgb = rgb2cam^-1;
lin_srgb = apply_cmatrix(lin_rgb, cam2rgb);
lin_srgb = max(0,min(lin_srgb,1)); % Always keep image clipped b/w 0-1

%% Code to make HDR starts here:

% Resize the image to make computation faster
small = imresize(lin_srgb, 0.2, 'bicubic');

% Convert RGB to gray, used for brightening
grayim = rgb2gray(small);

% Initializing 2 arrays (one for images, second for names)
array = zeros(size(grayim, 1), size(grayim, 2), 3, 6);
sampleImg = {0; 0; 0; 0; 0; 0}; 

% Create multiple images with different brightness levels
% These will be used as inputs for the makehdr function
for i = 0:5
    imgNum = strcat('0', num2str(i+1));
    sampleImg{i+1} = strcat('nl_srgb', imgNum, '.bmp'); % save as bitmap image, because it is lossless and uncompressed
    j = i * 25 + 5; % Create different brightness values
    grayscale = j * mean(grayim(:));
    bright_srgb = min(1,small*grayscale); % Brighten depending on the brighness value
    array(:,:,:,i+1) = srgbGamma(bright_srgb); % call srgbGamma to return a gamma corrected RGB image
    imwrite(array(:,:,:,i+1), sampleImg{i+1});
    
    % Displaying the sample images of different brightness levels
    if i == 0
        axes(handles.axes2);
    end
    
    if i == 1
        axes(handles.axes3);
    end
    
    if i == 2
        axes(handles.axes4);
    end
    
    if i == 3
        axes(handles.axes5);
    end
    
    if i == 4
        axes(handles.axes6);
    end
    
    if i == 5
        axes(handles.axes7);
    end
    
    imshow(array(:,:,:,i+1));
end

% Relative exposure values to use for makehdr. Since we
% don't actually have separate exposure, we have to use relative exposures
exptimes = [0.3, 0.6, 0.9, 1.2, 1.5, 1.8]; 

% Make an HDR image, and tonemap to make it displayable 
hdr = makehdr(sampleImg, 'RelativeExposure', exptimes ./exptimes(1)); 

% Make sliders for the user to adjust lightness and saturation
satValue = get(handles.slider1, 'Value');
lightValue = get(handles.slider3, 'Value');

tonemapped = tonemap(hdr, 'AdjustSaturation', satValue, 'AdjustLightness', [lightValue 1]);

% Defining a global variable for the result HDR image
global resultImg;
resultImg = tonemapped;

axes(handles.axes1);
imshow(tonemapped);


% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
quit;


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

prompt = 'Enter the file name:';
dlg_title = 'Input';
num_lines = 1;
def = {'HDR_Image'};
answer = inputdlg(prompt,dlg_title,num_lines,def);
answer = strcat(answer, '.png');  % Save image as png
filename = answer{1};
global resultImg;
imwrite(resultImg, filename);


% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider3_Callback(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end
