clc; close all; clear all; format long e;

% -------------------------------------------------------------------------
%                  Add the Current Path to Workspace
% -------------------------------------------------------------------------

pre_define_the_path_for_folders

% -------------------------------------------------------------------------
%                  Inputs for Simulation
% -------------------------------------------------------------------------
freq = [1e0 2.5e0 5e0 7.5e0 1e1 2.5e1 5e1 7.5e1 1e2 2.5e2 5e2 7.5e2 ...
    1e3 2.5e3 5e3 7.5e3 1e4 2.5e4 5e4 7.5e4 1e5 2.5e5 5e5 7.5e5 ...
    1e6 2.5e6 5e6 7.5e6 1e7 2.5e7 5e7 7.5e7 1e8 2.5e8 5e8 7.5e8 ...
    1e9 2.5e9 5e9 7.5e9 1e10] ; % frequency
num_freq = length(freq);
er = 0;  % epsilon_r of conductors
se=5.8e7; % conductivity of conductors
inner_it = 100; outer_it = 10; tol=1e-12; % iterative solver inputs
Res = 0.5e-6; % voxel size (deltax)
fl_check_domain=0; % set to 1 for only plotting the structure (no simulation)
fl_check_geo=0; % set to 1 for only plotting the domain (no simulation)
fl_check_ports=0; % set to 1 for only plotting the port nodes (no simulation)
plot_option=1; % see the options of plotting in Visualization part
freq_curr_plot=2.5e9; % frequency for plotting currents
simple_post_proc = 0; % if 1, just plot the current densities in 3D

% -------------------------------------------------------------------------
%                  Inputs for the Structure
% -------------------------------------------------------------------------
% We only need centers (Cnt), dimensions (Dims), and orientations (Orients)
% of the conductors at the end of this part.

% inputs for generating conductors with specified lengths and widths of arms
num_conds = 1; % number of conductors
num_ports = 1; % number of ports
len_cond=30.0e-6; % length of conductors
width_cond=10.0e-6; % width of conductor
height_cond=10.0e-6; % height of conductor
dist_btw_conds=20.0e-6; % distance between centers of conductors
cen_cond1=[len_cond/2 width_cond/2 height_cond/2];
Cnt = [cen_cond1;]; % centers of conductors
for kk=1:num_conds-1
    for ll=1:1
        Cnt=[Cnt; [Cnt(ll,1) Cnt(ll,2)+kk*dist_btw_conds Cnt(ll,3)]];
    end
end

Dims_tmp = [len_cond width_cond height_cond;]; % dimensions of conductors(L(x),W(y),H(z))
Orients_tmp=['x';]; % orientations of conductors
Dims=[]; Orients=[];
for kk=1:num_conds
    Dims=[Dims;Dims_tmp];
    Orients=[Orients;Orients_tmp];
end

% -------------------------------------------------------------------------
%                  Input for Computational Domain
% -------------------------------------------------------------------------
% At the end of this part, we only need bbox_min(3) and bbox_max(3) vectors
% define computational domain or bounding box enclosing the structure
bbox_min=[0 0 0]; % minimum coordinates of bounding box (bbox) - set to positive reals if possible
bbox_max=[len_cond (num_conds-1)*dist_btw_conds+width_cond height_cond]; % max coordinates of bbox

% -------------------------------------------------------------------------
%                  Input for Ports
% -------------------------------------------------------------------------
% At the end of this part, we need structures pnt_lft{xx} and pnt_rght{xx} which
% contains the coordinates of nodes on both sides of xxth port

% defining the nodes in first port
pnt_lft=cell(num_ports,1);
pnt_rght=cell(num_ports,1);
pnt_lft{1}=zeros(round(width_cond/Res)*round(height_cond/Res),3);
pnt_rght{1}=zeros(round(width_cond/Res)*round(height_cond/Res),3);
dum=1;
for kk=1:round(width_cond/Res)
    for ll=1:round(height_cond/Res)
        pnt_rght{1}(dum,1:3)=[len_cond (2*kk-1)*(0.5*Res) (2*ll-1)*(0.5*Res)]; % points on which excitation defined
        pnt_lft{1}(dum,1:3)=[0 (2*kk-1)*(0.5*Res) (2*ll-1)*(0.5*Res)]; % points on which ground defined
        dum=dum+1;
    end
end

% defining the nodes in remaining ports
for kk=2:num_ports
    pnt_lft{kk}(:,2)=pnt_lft{1}(:,2) + dist_btw_conds*(kk-1);
    pnt_lft{kk}(:,[1 3])=pnt_lft{1}(:,[1 3]);
    pnt_rght{kk}(:,2)=pnt_rght{1}(:,2) + dist_btw_conds*(kk-1);
    pnt_rght{kk}(:,[1 3])=pnt_rght{1}(:,[1 3]);
end

% defining nodes connected ground if conductors without ports exist; if
% there is no, then leave as a empty array.

%pnt_well_cond=[pnt_lft{1}(1,1) pnt_lft{1}(1,2) + dist_btw_conds pnt_lft{1}(1,3);];
pnt_well_cond=[];

% -------------------------------------------------------------------------
%                         Initialize stuff
% -------------------------------------------------------------------------

pre_print_out_inputs_generate_consts

% -------------------------------------------------------------------------
%                   Define domain and constitutive parameters
% -------------------------------------------------------------------------

% generate domain 3D grid
[r] = generategridfrombbox(Res,[bbox_min(1) bbox_max(1)],[bbox_min(2) bbox_max(2)],[bbox_min(3) bbox_max(3)],fl_check_domain);

% assign constitutive parameters
[idx,epsilon_r,sigma_e,grid_intcon] = intcon_constparams(r,Res,Cnt,Dims,Orients,er,se,fl_check_geo);

if (fl_check_domain == 1 || fl_check_geo == 1); return; end;

% -------------------------------------------------------------------------
%                 Define EM Vars/Constants and Domain Parameters
% -------------------------------------------------------------------------

pre_define_structure_params
tinisim = tic;
% ------------------------------------------------------------------------
%                  Obtain Nodal Incidence Matrix
% -------------------------------------------------------------------------
tini = tic;
[Ae_original,nodeid_lft,nodeid_rght,nodeid_wlcond,Ae_only_leaving,Ae_only_entering_bndry] = lse_compute_Ae_matrix(idxS, grid_intcon, L, M, N, dx, pnt_lft,pnt_rght,pnt_well_cond,fl_check_ports);
if (fl_check_ports == 1); return; end;
tend = toc(tini);
disp(['Time for generating Ae mat & finding IDs of port nodes::: ' ,num2str(tend)]);

sim_CPU_pre(1)=toc(tinisim); % CPU time for Ae

% ------------------------------------------------------------------------
%              Precomputation of LSE data
% -------------------------------------------------------------------------
tinisim = tic;
disp('-----------------------------------------------------')
disp(['Precomputing LSE data structures...'])
tinix = tic;
rhs_vect=zeros(size(Ae_original,1)+size(Ae_original,2),num_ports);
for port_no=1:num_ports

    Ae = Ae_original;
    
    % ------------------------------------------------------------------------
    %              Assign Excitation and Ground Nodes
    % ------------------------------------------------------------------------
    
    [nodeid_4_grnd,nodeid_4_injectcurr]=lse_assign_exc_grnd_nodes(nodeid_lft,nodeid_rght,nodeid_wlcond,num_ports,port_no);
    
    % ------------------------------------------------------------------------
    %                  Set Excitation (V)
    % ------------------------------------------------------------------------
    
    [rhs_vect(:,port_no)] = lse_compute_rhs_vector(Ae,nodeid_4_injectcurr);
   
    % ------------------------------------------------------------------------
    %         Generate Circulant Tensors
    % -------------------------------------------------------------------------
    
    if (port_no == 1)
        tini = tic;
        if (num_freq == 1)
            fl_no_fft=0;
            [fN_all,st_sparse_precon] = lse_generate_circulant_tensor(dx,ko,L,M,N,fl_no_fft);
        else
            fl_no_fft=1;
            [fN_all2,st_sparse_precon2] = lse_generate_circulant_tensor(dx,1,L,M,N,fl_no_fft);
            % note multiply fN_all and st_sparse_precon with ko^2 and compute its FFT
        end
        tend = toc(tini);
        disp(['Total time for getting circulant tensor ::: ' ,num2str(tend)]);

    end
    
    if (port_no == num_ports)
        Ae = Ae_original;
        % Remove rows and columns of Ae corresponding to ground and excitation nodes
        Ae(nodeid_4_grnd,:)=0;
        Ae(nodeid_4_injectcurr,:)=0;
        clear Ae_original
    end
end

tendx = toc(tinix);
disp(['Total time for getting precomputed LSE data ::: ' ,num2str(tendx)]);
disp(['Done... Precomputing LSE data structures'])
disp('-----------------------------------------------------')
sim_CPU_pre(2)=toc(tinisim); % CPU time for circulant+rhs

disp('-----------------------------------------------------')
disp(['Solving LSEs ...'])

Y_mat=zeros(num_ports,num_ports,num_freq);
Y_mat2=zeros(num_ports,num_ports,num_freq);
Z_mat=zeros(num_ports,num_ports,num_freq);
R_jL_mat=zeros(num_ports,num_ports,num_freq);
for freq_no=1:num_freq
    tinisim = tic;
    if (num_freq > 1)
        freq = freq_all(freq_no);
        if (freq < 1e6)
            tol = 1e-12;
        else
            tol = 1e-8;
        end
    end
    EMconstants
    disp('-----------------------------------------------------')
    disp(['Simulation for frequency : ',num2str(freq),' started! ', 'freq pnt: ',num2str(freq_no), ' / ', num2str(num_freq)])
    
    % setting new constitutive parameters for new freq
    Mr = epsilon_r - 1j*sigma_e/(eo*omega); % permittivity
    Mc = Mr - 1.0; % susceptibility
    OneoverMc = 1.0 ./ Mc; % one over susceptibility
    
    % circulant tensor for the current frequency
    if (num_freq > 1)
        fN_all = fN_all2*(ko^2);
        fN_all = fft_operator(fN_all);
        st_sparse_precon = st_sparse_precon2 * (ko^2);
    end
    sim_CPU_lse(freq_no,1,1)=toc(tinisim); % CPU time for FFT + prep data
    
    for port_no=1:num_ports
        disp(['Solving for port # ',num2str(port_no), ' ...'])

        
        % ------------------------------------------------------------------------
        %              Assign Excitation and Ground Nodes
        % ------------------------------------------------------------------------
        
        [nodeid_4_grnd,nodeid_4_injectcurr]=lse_assign_exc_grnd_nodes(nodeid_lft,nodeid_rght,nodeid_wlcond,num_ports,port_no);
        
        % ------------------------------------------------------------------------
        %     Solve Linear System of Equations Iteratively
        % -------------------------------------------------------------------------
        
        if (port_no == 1)
            % prepare the preconditioner
            tinisim = tic;
            lse_sparse_precon_prepare(dx,freq,OneoverMc,idxS3,st_sparse_precon,nodeid_4_grnd,nodeid_4_injectcurr,Ae);
            sim_CPU_lse(freq_no,port_no,2)=toc(tinisim); % CPU time for sparse_precon
        end
        tinisim = tic;
        % Solve the system iteratively
        % Define the handle for matvect
        fACPU   = @(J)lse_matvect_mult(J, fN_all, Ae, OneoverMc, dx, freq, idxS5, nodeid_4_grnd, nodeid_4_injectcurr);
        tini = tic;
        disp(['Iterative solution started ... '])
        [rhs_vect_sparse_precon]=lse_sparse_precon_multiply(rhs_vect(:,port_no),Ae,nodeid_4_grnd,nodeid_4_injectcurr);
        [x, flag, relres, iter, resvec] = pgmres(@(J)fACPU(J), rhs_vect_sparse_precon, inner_it, tol, outer_it);
        tend = toc(tini);
        disp(['Total time for iterative solution ::: ' ,num2str(tend)]);
        disp(['Done... Iterative solution'])
        sim_CPU_lse(freq_no,port_no,3)=toc(tinisim); % CPU time for iterative solver
        if (abs(freq_curr_plot-freq)<1e-12 && port_no == 1)
            x_backup = x;
        end
        % ------------------------------------------------------------------------
        %     Compute the Currents on Port Nodes and the Column in Ymat
        % -------------------------------------------------------------------------

        currs_port_yparams=zeros(num_ports,1);
        for kk=1:num_ports
            currs_port_yparams(kk,1)=sum(rhs_vect(:,kk).*x);
        end
        
        Y_mat(:,port_no,freq_no)=currs_port_yparams(:,1);
        
        % remove the following later on! not needed!
        % compute column w/ alternative way - just for double checking
        [currs_port_yparams2] = lse_compute_Y_mat_column_alternative(num_ports,Ae,Ae_only_leaving,Ae_only_entering_bndry,x,nodeid_lft,currs_port_yparams);
  
        
        disp(['Done... Solving for port # ',num2str(port_no)])
    end
    disp('-----------------------------------------------------')
    disp(['Done... Simulation for frequency : ',num2str(freq),' freq pnt: ',num2str(freq_no), ' / ', num2str(num_freq)])
    
    Z_mat(:,:,freq_no)=inv(squeeze(Y_mat(:,:,freq_no)));
    R_jL_mat(:,:,freq_no)=abs(real(squeeze(Z_mat(:,:,freq_no))))+sqrt(-1)*abs(imag(Z_mat(:,:,freq_no))/(2*pi*freq));
end

disp(['Done... Solving LSEs'])
disp('-----------------------------------------------------')

for freq_no=1:num_freq
    disp(['R+jL matrix for frequency = ',num2str(freq_all(freq_no))])
    for kk=1:num_ports
        disp([num2str(R_jL_mat(kk,:,freq_no))])
    end
end

% ------------------------------------------------------------------------
%                         Storing Data
% -------------------------------------------------------------------------

disp('-----------------------------------------------------')
disp(['Saving Data...'])

% R+jL matrices
save('results_numex1_straight_conductor/data_R_jL_mat.mat', 'num_freq', 'num_ports','freq_all','R_jL_mat');

% CPU timings
save('results_numex1_straight_conductor/data_CPU_timings.mat', 'num_freq', 'num_ports','sim_CPU_pre','sim_CPU_lse');

% CPU timings
save('results_numex1_straight_conductor/data_curr_plot.mat', 'x', 'Ae_only_leaving','Ae_only_entering_bndry','r','Mc','dx','plot_option');

disp(['Done... Saving data'])
disp('-----------------------------------------------------')

if(simple_post_proc == 1)
    %% ------------------------------------------------------------------------
    %                         Visualization
    % -------------------------------------------------------------------------

    disp('-----------------------------------------------------')
    disp(['Plotting Current Distribution...'])

    close all

    % select plotting option - check the subroutines below for more options
    % option 1-> total currents on 3D structure, - no cut selection required
    % option 2-> current coefficients on the voxels - select plane and cut
    % option 3-> currents on the nodes via imagesc - select plane and cut
    % option 4-> currents on the nodes via quiver - select plane and cut
    % option 5-> currents on the structure w/directions via quiver3 - no cut selection required
    % voxels (on a selected cut), 3-> currents on nodes w/scalar values (on a selected cut) ,
    % plot_option=1;

    % set x_backup to x
    x = x_backup;

    % if any of plot option 2,3,4 is selected, define plane and cut
    slct_plane='xy'; %'xz'; 'yz';
    if (plot_option == 2 || plot_option == 3)
        % 1) use the following for plot option 2 and 3
        slct_cut=round(N/2);% round(M/2); round(L/2);
    elseif (plot_option == 4)
        % 2) use the following for plot option 4 - we need coordinate of the cut
        slct_cut=squeeze(r(1,1,N,3)); % z-coordinate of cut % squeeze(r(round(L/2),1,1,1)); % x-coordinate of cut; squeeze(r(1,round(M/2),1,2)); % y-coordinate of cut
    end

    if (plot_option == 2)
        % sort current coefficients on voxels
        [Jx_currs_grid,Jy_currs_grid,Jz_currs_grid,J2d_currs_grid,J3d_currs_grid,cmin,cmax]=post_obtain_curr_coefs_on_grid(x,Mc);
    elseif (plot_option > 2)
        % obtain currents on nodes
        [nodes_w_currs_x_aligned,nodes_w_currs_y_aligned,nodes_w_currs_z_aligned]=post_obtain_currs_on_nodes(x,Ae_only_leaving,Ae_only_entering_bndry,r,Mc,dx);
    end

    switch plot_option
        case 1
            % 1) Plot currents on structure
            % Plot total currents as one scalar on each voxel
            plot_currs_on_3D_structure(x,Ae_only_leaving,r,Mc,dx)
        case 2
            % 2) Plot current coefficients obtained via iterative solution
            plot_curr_coefs_on_grid(slct_plane,slct_cut,r,Jx_currs_grid,Jy_currs_grid,Jz_currs_grid,J2d_currs_grid,J3d_currs_grid,cmin,cmax);
        case 3
            % 3) Plot currents with scalar values via imagesc
            plot_curr_on_nodes(slct_plane,slct_cut,dx,nodes_w_currs_x_aligned,nodes_w_currs_y_aligned,nodes_w_currs_z_aligned)
        case 4
            % 4) Plot currents on cuts w/ directions via quiver
            plot_curr_on_nodes_quiver(slct_plane,slct_cut,nodes_w_currs_x_aligned,nodes_w_currs_y_aligned,nodes_w_currs_z_aligned)
        case 5
            % 5) Plot currents on the structure w/directions via quiver3
            plot_curr_on_nodes_quiver3(nodes_w_currs_x_aligned,nodes_w_currs_y_aligned,nodes_w_currs_z_aligned)
        otherwise
            disp('No current plotting!')
    end

    disp(['Done... Plotting Current Distribution'])
    disp('-----------------------------------------------------')

else
    % Execute postprocessor
    post_processor_numex1
end
