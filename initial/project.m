filename = 'girl.dng'; % Put file name here
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

black = meta_info.SubIFDs{1}.BlackLevel(1);
saturation = meta_info.SubIFDs{1}.WhiteLevel;
lin_bayer = (raw-black)/(saturation-black);
lin_bayer = max(0,min(lin_bayer,1));

wb_multipliers = (meta_info.AsShotNeutral).^-1;
wb_multipliers = wb_multipliers/wb_multipliers(2);
mask=wbmask(size(lin_bayer,1),size(lin_bayer,2),wb_multipliers(1),wb_multipliers(3));
balanced_bayer = lin_bayer .* mask;

temp = uint16(balanced_bayer/max(balanced_bayer(:))*2^16);
lin_rgb = double(demosaic(temp,'rggb'))/2^16;

xyz2cam = [meta_info.ColorMatrix2(1) meta_info.ColorMatrix2(2) meta_info.ColorMatrix2(3);
           meta_info.ColorMatrix2(4) meta_info.ColorMatrix2(5) meta_info.ColorMatrix2(6);
           meta_info.ColorMatrix2(7) meta_info.ColorMatrix2(8) meta_info.ColorMatrix2(9)]; % make matrix

rgb2xyz = [0.4124564 0.3575761 0.1804375; 
           0.2126729 0.7151522 0.0721750; 
           0.0193339 0.1191920 0.9503041];

rgb2cam = xyz2cam * rgb2xyz; % Assuming previously defined matrices
rgb2cam = rgb2cam ./ repmat(sum(rgb2cam,2),1,3); % Normalize rows to 1
cam2rgb = rgb2cam^-1;
lin_srgb = apply_cmatrix(lin_rgb, cam2rgb);
lin_srgb = max(0,min(lin_srgb,1)); % Always keep image clipped b/w 0-1

%grayim = rgb2gray(lin_srgb);
%grayscale = 0.25/mean(grayim(:)); % uses mean for brightenning, we don't
%want that
%bright_srgb = min(1,lin_srgb*grayscale);
%nl_srgb = srgbGamma(bright_srgb);

%variations on the tutorial begin here:

small = imresize(lin_srgb, .2, 'bicubic');

onlyGamma = srgbGamma(small); % this produces a flat image, but it has details in the highlights

% what happens if we brighten after gamma correction? looks better, still
% too blown out, not using currently
grayim = rgb2gray(onlyGamma);
grayscale = 0.25/mean(grayim(:)); 
bright_srgb = min(1,onlyGamma*grayscale);



A = imadjust(onlyGamma,[],[],.4);
B = imadjust(onlyGamma,[],[],.6);
C = imadjust(onlyGamma,[],[],.8);
D = imadjust(onlyGamma,[],[],1);
E = imadjust(onlyGamma,[],[],1.2);
F = imadjust(onlyGamma,[],[],1.4);


imwrite(A, 'A.png');
imwrite(B, 'B.png');
imwrite(C, 'C.png');
imwrite(D, 'D.png');
imwrite(E, 'E.png');
imwrite(F, 'F.png');

files = {'A.png','B.png','C.png','D.png','E.png','F.png'};

exptimes = [.4, .6, .8, 1, 1.2, 1.4];

hdr = makehdr(files, 'RelativeExposure', exptimes ./exptimes(1));
tonemapped = tonemap(hdr, 'AdjustSaturation', 2);
imshow(tonemapped);

imwrite(tonemapped, 'tonemapped.png');

