%   Constructs an outer polytope that approximates the set of all
%   assemblages generated by locally performing N 2-outcome planar
%   projective measurements on the two-qubit state rho_AB.
%   Calculates a lower bound for the critical visibility of the input
%   two-qubit state when subjected to sets of N 2-outcome planar projective
%   measurements.
%   
%   authors:     Jessica Bavaresco, Marco Tulio Quintino, Leonardo Guerini,
%                Thiago O. Maciel, Daniel Cavalcanti, Marcelo Terra Cunha
%
%   requires:    Yalmip (https://yalmip.github.io) and QETLAB (http://www.qetlab.com)
%
%   last update: May, 2017

function eta = polyapprox_qubit_planproj(rho_AB, num)
%polyapprox_qubit_proj Calculates a lower bound to the critical visibility
%   of the input two-qubit state rho_AB when subjected to N 2-outcome
%   projective measurements by constructin an outer polytope que
%   approximate the set of assemblages. This code is written for the
%   specific case of N=5 and will need editing to calculate lower bounds
%   for different number of measurements. Details follow.
%
%   INPUT: rho_AB = bipartite two-qubit state
%             num = number of extremal points in the polytope that
%             approximates the XZ plane of the Bloch sphere.
%             
%
%   OUTPUT:  eta = lower bound for the critical visibility
%            optional: the code can be modified to output LHS models for
%            the extremal points of the polytope that are already being
%            calculated.

% the function polytope_vertices_plan will calculate the vertices of a polytope
% that involves the Bloch sphere based on the input vectors. See polytope_vertices
% for details
vert     = polytope_vertices_plan(num);
num_vert = size(vert,1); % reads the number of extremal points

dA   = 2; % Alice's system must be dimension 2
k    = 2; % Two-outcome qubit projective measurements
N    = 5; % Number of measurements is 5 but can be modified
M_ax = zeros(dA,dA,N,k);

XX = [0 1; 1 0];  % Pauli matrices
ZZ = [1 0; 0 -1]; % Pauli matrices

% first measurements is fixed and constructed from the first extremal point
% vert(1,:)
M_ax(:,:,1,1) = (1/2)*(eye(2)+vert(1,1)*XX+vert(1,2)*ZZ);
M_ax(:,:,1,2) = (1/2)*(eye(2)-vert(1,1)*XX-vert(1,2)*ZZ);

% the set of measurements is constructed by a cartesian product between all
% measurements that can be constructed from the extremal points of the
% polytope. This version constructs sets of 5 quasi-POVMs, but can be modified 
% for other numbers. Each measurement requires a nested for loop and an if
% statement.
t = 1;
for i=2:num_vert
    M_ax(:,:,2,1) = (1/2)*(eye(2)+vert(i,1)*XX+vert(i,2)*ZZ);
    M_ax(:,:,2,2) = (1/2)*(eye(2)-vert(i,1)*XX-vert(i,2)*ZZ);
    
    for j=2:num_vert
        if j~=i
            M_ax(:,:,3,1) = (1/2)*(eye(2)+vert(j,1)*XX+vert(j,2)*ZZ);
            M_ax(:,:,3,2) = (1/2)*(eye(2)-vert(j,1)*XX-vert(j,2)*ZZ);
        
            for k=2:num_vert
                if k~=i && k~=j 
                    M_ax(:,:,4,1) = (1/2)*(eye(2)+vert(k,1)*XX+vert(k,2)*ZZ);
                    M_ax(:,:,4,2) = (1/2)*(eye(2)-vert(k,1)*XX-vert(k,2)*ZZ);
            
                    for l=2:num_vert
                        if l~=i && l~=j && l~=k
                            M_ax(:,:,5,1) = (1/2)*(eye(2)+vert(l,1)*XX+vert(l,2)*ZZ);
                            M_ax(:,:,5,2) = (1/2)*(eye(2)-vert(l,1)*XX-vert(l,2)*ZZ);
            
                            % SDP wnr_eta will calculate the critical
                            % visibility of the state rho_AB subjected to
                            % each set of quasi-POVMs that was constructed
                            % and store the values on the vector eta_list
                            eta_list(t,1) = wnr_eta(rho_AB, M_ax)
                            t = t + 1;
                        end
                    end
                end
            end
        end
    end
end

% each value in eta_list is the critical visibility of one of the extremal
% points in the polytope that approximates the set of assemblages generated
% from state rho_AB in the specified scenario. The minimum among them, eta,
% is a lower bound for the critical visibility of the state rho_AB
% subjected to N=5 planar projective qubit measurements.
eta = min(eta_list);

end

function vert = polytope_vertices_plan(N)
%polytope_vertices_plan Generates a polytope that approximates the XZ plane
%   of the Bloch sphere with N extremal points. The polytope is guaranteed
%   to contain the XZ plane.
%
%   INPUT:  N number of extremal points in the polytope approximation  
%   OUTPUT: vert = is a set of vectors that define the polytope that
%           contains the XZ plane of the Bloch sphere

r   = zeros(N,2);
phi = 0:2*pi/N:2*pi-2*pi/N;

for i=1:N
    r(i,:) = (1/2)*[sin(phi(i)) cos(phi(i))];
end
r(:,3) = 1/2;

H = struct('A',r(:,1:2),'B',r(:,3),'lin',1:0);
V = cddmex('extreme',H);
V = V.V;

num = size(V);
num = num(1);
vert = zeros(num/2,2);

for i=1:num
    for j=1:2
        V(i,j) = round(V(i,j)*10^6)./10^6;
    end
end

for i=2:num
    for j=1:i-1
        if V(i,:)==-V(j,:)
            V(i,:)=zeros(1,2);
            break
        end
    end         
end

% the polytope is guaranteed to be formed by pairs of antipodal vectors in
% order to construct qubit 2-outcome projective measurements.
t = 1;
for i=1:num
    if V(i,1)~=0||V(i,2)~=0
       vert(t,:) = V(i,:);
       t = t+1;
    end
end

end

function eta = wnr_eta(rho_AB, M_ax)
%wnr_ste Calculates the critical visibility eta of the quantum
%   state rho_AB subjected to local measurements M
%
%   INPUT:   rho_AB = quantum state 
%                 M = set of measurements
%  
%   OUTPUT:     eta = critical visibility

dA = size(M_ax,1);
dB = size(rho_AB,1)/dA;
N  = size(M_ax,3);
k  = size(M_ax,4);
D  = zeros(N,k,k^N);

yalmip('clear');

% variables are visibility eta and assemblage in the LHS model
sdpvar eta
sig_loc = sdpvar(dB,dB,k^N,'hermitian','complex');

% generates deterministic probability distribution
F = [];
for l=1:k^N
    F = F + [sig_loc(:,:,l)>=0]; % positivity constraint on the elements of the assemblage in the LHS model
    string = dec2base(l-1,k,N);
    for i=1:N
        c = str2double(string(i));
        D(i,c+1,l) = 1;
    end
end

for i=1:N
    for j=1:k
        sig_ax = PartialTrace(kron(M_ax(:,:,i,j),eye(dB))*rho_AB,1,[dA dB]);
        uns_ax = zeros(dB,dB);
        for l=1:k^N
            uns_ax = uns_ax + D(i,j,l)*sig_loc(:,:,l);
        end
        F = F + [uns_ax==eta*sig_ax+((1-eta)/dB)*trace(sig_ax)*eye(dB)];
    end
end

J = eta;

% maximizes the visibility such that the assemblage generated by input state
% state and measurements accepts a LHS model
SOLUTION = solvesdp(F, -J, sdpsettings('solver','mosek','verbose',0));

eta = double(J);

end
