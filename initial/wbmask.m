function colormask = wbmask(m,n,r_scale,b_scale)
% COLORMASK = wbmask(M,N,R_SCALE,B_SCALE)
%
% Makes a white-balance multiplicative mask for an RGGB image of size m-by-n with
% white balance scaling values R_SCALE, G_SCALE=1, and B_SCALE.
colormask = ones(m,n);
colormask(1:2:end,1:2:end) = r_scale;
colormask(2:2:end,2:2:end) = b_scale;
end
