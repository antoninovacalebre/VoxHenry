% Domain and unknown parameters
[L,M,N,~] = size(sigma_e); % domain size
nD = L*M*N; % number of variables in the system
% the voxels with non-zero conductivity
sigma_e_nonzero = abs(sigma_e(:)) > 1e-12;
if isempty(lambdaL)
    % the indices of the non-air voxel positions (where either sigma or lambdaL or both are non-null)
    idxS = find(sigma_e_nonzero);
else
    %the voxels with non-zero Londpn penetration depth 
    lambdaL_nonzero = abs(lambdaL(:)) > 1e-12; 
    % the indices of the non-air voxel positions (where either sigma or lambdaL or both are non-null)
    idxS = find(sigma_e_nonzero | lambdaL_nonzero); 
end
%idxS3 = [idxS; nD+idxS; 2*nD+idxS]; % the vector of non-air positions for 3 Cartesian components
idxS5 = [idxS; nD+idxS; 2*nD+idxS; 3*nD+idxS; 4*nD+idxS]; % for currents

if exist('Bfield_source_enabled', 'var') == 1 && Bfield_source_enabled
    for i=1:length(idxS)
        id = idxS(i);
    
        ix = mod(mod((id - 1), L*M), L);
        iy = floor(mod((id - 1), L*M)/L);
        iz = floor((id - 1)/(L*M));
    
        xyz(i, 1) = (ix + 0.5) * dx;% - L*dx/2;
        xyz(i, 2) = (iy + 0.5) * dx;% - L*dx/2;
        xyz(i, 3) = (iz + 0.5) * dx;% - L*dx/2;
    end
    
    Ex_ext = @(x,y,z,omega) -(1j * omega) * Bfield(2) * z;
    Ey_ext = @(x,y,z,omega) -(1j * omega) * Bfield(3) * x;
    Ez_ext = @(x,y,z,omega) -(1j * omega) * Bfield(1) * y;
    
    Ex = Ex_ext(xyz(:,1),xyz(:,2),xyz(:,3),omega);
    Ey = Ey_ext(xyz(:,1),xyz(:,2),xyz(:,3),omega);
    Ez = Ez_ext(xyz(:,1),xyz(:,2),xyz(:,3),omega);
    
    Vx = Ex / dx;
    Vy = Ey / dx;
    Vz = Ez / dx;
end

% Constitutive parameters
% due to lowest frequency if multiple frequency is defined

% 'epsilon_r' 3D matrix is not strictly needed for the simulation - might use simply zero
% however it is used for post-processing visualization (through 'Mc', see VoxHenry_executer.m)
epsilon_r = ones(size(sigma_e));
epsilon_r(idxS) = 0.0;


