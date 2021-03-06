%   Search algorithm to find optimal set of N 3-outcome trine measurements
%   to steer a given two-qubit state rho_AB. The optimal set is the one that,
%   when locally applied to state rho_AB, will generate the assemblage that
%   is most robust to white noise. Calculates an upper bound for the
%   critical visibility of the input two-qubit state when subjected to
%   sets of N 3-outcome trine measurements.
%   
%   authors:     Jessica Bavaresco, Marco Tulio Quintino, Leonardo Guerini,
%                Thiago O. Maciel, Daniel Cavalcanti, Marcelo Terra Cunha
%
%   requires:    Yalmip (https://yalmip.github.io) and QETLAB (http://www.qetlab.com)
%
%   last update: May, 2017

function [opt_M, eta] = search_qubit_trine(rho_AB, N)
%search_qubit_trine Calculates a lower bound for the critical visibility
%   eta of a two-qubit quantum state rho_AB subjected to N 4-outcome
%   trine measurements using a search algorithm and finds a candidate to the
%   optimal set of measurements.  The optimization tool is the MATLAB
%   function fminsearch.  The variable is a vector of parameters that define
%   a set of N 3-outcome trine measurements and the objective
%   function is the result of SDP wnr_eta.
%
%   INPUT: rho_AB = bipartite quantum state
%               N = number of tetrahedron measurements     
%
%   OUTPUT: opt_M = optimal set of measurements opt_M
%             eta = upper bound for the critical visibility 

rng('shuffle');      % shuffles list of "random numbers"

dA = 2;              % Alice's system must have dimension 2
k  = 3;              % 3-outcome qubit trine measurements
np = 3*N;            % total number of parameters in the parameter vector x
x0 = pi*rand(np,1);  % random initial values for the parameter vector x

options = optimset('MaxFunEvals',100000,'MaxIter',100000,'TolX',1e-5,'TolFun',1e-6);
% options can be specified by user

[a,fval,flag] = fminsearch(@(x)wnr_qubittrine(x,rho_AB,N),x0,options);
% calls fminsearch to optimize over function wnr_qubittrine given initial
% value x0 for the parameter vector x in the optimization.
% output vector a is the optimal value for parameter vector x and fval is
% the optimal value of the objective function: the critical visibility eta

psi   = zeros(dA,dA);
opt_M = zeros(dA,dA,N,k); % opt_M(:,:,i,j) is the jth outcome of the ith measurement in the set opt_M

% reconstructing optimal measurements from the optimal parameter vector a
t = 1;
for i=1:N
    psi(:,1) = [cos(a(t)/2); exp(1i*a(t+1))*sin(a(t)/2)];
    psi(:,2) = [-exp(-1i*a(t+1))*sin(a(t)/2); cos(a(t)/2)];           
    
    % best candidate to the optimal set of measurements
    opt_M(:,:,i,1) = (2/3)*(psi(:,1)*psi(:,1)');
    opt_M(:,:,i,2) = (2/3)*(cos(pi/3)*psi(:,1)+exp(1i*a(t+2))*sin(pi/3)*psi(:,2))*(cos(pi/3)*psi(:,1)+exp(1i*a(t+2))*sin(pi/3)*psi(:,2))';
    opt_M(:,:,i,3) = eye(dA) - sum(opt_M(:,:,i,1:k-1),4);

    t = t + 3;
end

% upper bound for the critical visibility of rho_AB subjected to N 3-outcome trine
% measurements is the optimal value of the objective function in the optimization
eta = fval;

end

function eta = wnr_qubittrine(x,rho_AB,N)
%wnr_qubittrine Is the function called by fminsearch. It constructs sets of 
%   N 3-outcome trine measurements M_ax from the parameter vector x.
%   Then it calls the SDP wnr_eta to calculate the critical visibility 
%   of the state rho_AB subjected to the set of measurements M_ax.
%   The output is the critical visibility calculated by the SDP.
%
%   INPUT:     x = vector of parameters over which fminsearch will optimize
%                  They define the set of measurements M_ax
%         rho_AB = bipartite quantum state
%              N = number of measurements in M_ax
%
%   OUTPUT:  eta = critical visibility of state rho_AB subjected to
%            mesurements M_ax that are defined from parameter vector x

dA   = 2;                 % Alice's system must have dimension 2
k    = 3;                 % 3-outcome qubit trine measurements
psi  = zeros(dA,dA);
M_ax = zeros(dA,dA,N,k); % M_ax(:,:,i,j) is the jth outcome of the ith measurement in the set M_ax

% constructs set of measurements M_ax from the vector of parameters x
t = 1;
for i=1:N
    psi(:,1) = [cos(x(t)/2); exp(1i*x(t+1))*sin(x(t)/2)];
    psi(:,2) = [-exp(-1i*x(t+1))*sin(x(t)/2); cos(x(t)/2)];           
    
    M_ax(:,:,i,1) = (2/3)*(psi(:,1)*psi(:,1)');
    M_ax(:,:,i,2) = (2/3)*(cos(pi/3)*psi(:,1)+exp(1i*x(t+2))*sin(pi/3)*psi(:,2))*(cos(pi/3)*psi(:,1)+exp(1i*x(t+2))*sin(pi/3)*psi(:,2))';
    M_ax(:,:,i,3) = eye(dA) - M_ax(:,:,i,1) - M_ax(:,:,i,2);
    for j=1:3
        M_ax(:,:,i,j) = (M_ax(:,:,i,j)+M_ax(:,:,i,j)')/2;
    end
    t = t + 3;
end

% calls SDP to calculate the critical visibility eta of state 
% rho_AB subjected to set of measurements M_ax
eta = wnr_eta(rho_AB, M_ax);

end

function eta = wnr_eta(rho_AB, M_ax)
%wnr_ste Calculates the critical visibility eta of the quantum
%   state rho_AB subjected to local measurements M_ax
%
%   INPUT:   rho_AB = quantum state 
%              M_ax = set of measurements
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
        % depolarization constraints
    end
end

J = eta;

% maximizes the visibility such that the assemblage generated by input state
% state and measurements accepts an LHS model
SOLUTION = solvesdp(F, -J, sdpsettings('solver','mosek','verbose',0));

eta = double(J);

end
