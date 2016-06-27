function out = srgbGamma(in)
% OUT = srgbGamma(in)
%
% Applies (inverse) sRGB gamma correction to an RGB image.
% Assumes input values are scaled between 0 and 1, return similar range.
in(in>1)=1; % Clip values to between 0-1
in(in<0)=0;
out = zeros(size(in));
nl=in>0.0031308;
out(nl)=1.055*(in(nl).^(1/2.4)) - 0.055;
out(~nl)=12.92*in(~nl);
end