%   Search algorithm to find optimal set of general N k-outcome measurements
%   to steer a given two-qubit state rho_AB. The optimal set is the one that,
%   when locally applied to state rho_AB, will generate the assemblage that
%   is most robust to white noise. Calculates an upper bound for the
%   critical visibility of the input two-qubit state when subjected to
%   arbitrary sets of N k-outcome measurements.
%   
%   authors:     Jessica Bavaresco, Marco Tulio Quintino, Leonardo Guerini,
%                Thiago O. Maciel, Daniel Cavalcanti, Marcelo Terra Cunha
%
%   requires:    Yalmip (https://yalmip.github.io) and QETLAB (http://www.qetlab.com)
%
%   last update: May, 2017

function [opt_M, eta] = search_qubit_genpovm(rho_AB, N, k)
%search_qubit_genpovm Calculates a lower bound for the critical visibility
%   eta of a two-qubit quantum state rho_AB subjected to general N k-outcome
%   measurements using a search algorithm and finds a candidate to the
%   optimal set of measurements.  The optimization tool is the MATLAB
%   function fminsearch. The variables are the parameters that define
%   a set of general N k-outcome measurements and the objective function
%   is the result of SDP wnr_eta.
%
%   INPUT: rho_AB = bipartite quantum state
%               N = number of measurements
%               k = number of outcomes of each measurement      
%
%   OUTPUT: opt_M = optimal set of measurements opt_M and
%             eta = upper bound for the critical visibility 

rng('shuffle');         % shuffles list of "random numbers"

dA = 2;                 % Alice's system must be dimension 2
np = (dA^2-1)*N*(k-1);  % total number of parameters in fminsearch
x0 = rand(np,1);        % random initial values for the parameters

options = optimset('MaxFunEvals',100000,'MaxIter',100000,'TolX',1e-5,'TolFun',1e-6);
% options can be specified by user

[a,fval,flag] = fminsearch(@(x)wnr_povm(x,rho_AB,N,k),x0,options)
% calls fminsearch to optimize over function wnr_povm given initial value x0
% for the parameters in the optimization
% output a is the optimal value for parameters x and fval is the optimal value
% of the objective function, in this case, eta

XX       = [0 1; 1 0];       % Pauli matrix
YY       = [0 -1i; 1i 0];    % Pauli matrix
ZZ       = [1 0; 0 -1];      % Pauli matrix
opt_M    = zeros(dA,dA,N,k); 
vec      = zeros(3,N,k);
gama     = zeros(N,k-1);
sum_vec  = zeros(3,N);
sum_gama = zeros(N,1);
alpha    = zeros(N,k);

% reconstructing optimal measurements from the optimal parameters a
t = 1;
for i=1:N
    for j=1:k-1
        gama(i,j)    = abs(a(t));
        vec(:,i,j)   = gama(i,j)*[sin(pi*a(t+1))*cos(2*pi*a(t+2)); sin(pi*a(t+1))*sin(2*pi*a(t+2)); cos(pi*a(t+1))];
        t            = t + 3;
        sum_vec(:,i) = sum_vec(:,i) + vec(:,i,j);
        sum_gama(i)  = sum_gama(i) + gama(i,j);
    end    
    vec(:,i,k) = - sum_vec(:,i);
    gama(i,k)  = norm(vec(:,i,k));
    sum_gama(i) = sum_gama(i) + gama(i,k);
end

for i=1:N
    for j=1:k
        alpha(i,j)     = 2*gama(i,j)/sum_gama(i);
        vec(:,i,j)     = vec(:,i,j)/norm(vec(:,i,j)); 
        % best candidate to the optimal set of measurements
        opt_M(:,:,i,j) = (1/2)*alpha(i,j)*(eye(dA)+vec(1,i,j)*XX+vec(2,i,j)*YY+vec(3,i,j)*ZZ);
    end
end

% upper bound for the critival visibility of rho_AB subjected to general N k-outcome measurements
eta = fval;

end

function eta = wnr_povm(x, rho_AB, N, k)
%wnr_povm Is the function called by fminsearch. It uses parameters x to 
%   define a set of general N k-outcome measurements M_ax. Then it calls SDP 
%   wnr_eta to calculate the critical visibility of the assemblage
%   generated by locally performing measurements M on state rho_AB. The
%   output is the critical visibility provided by the assemblage.
%
%   INPUT:     x = parameters over which fminsearch will optimize, define M
%         rho_AB = bipartite quantum state
%              N = number of measurements in M_ax
%              k = number of outcomes in each measurements in M_ax

dA       = 2;             % Alice's system must be dimension 2
XX       = [0 1; 1 0];    % Pauli matrix
YY       = [0 -1i; 1i 0]; % Pauli matrix
ZZ       = [1 0; 0 -1];   % Pauli matrix
M_ax     = zeros(dA,dA,N,k);
vec      = zeros(3,N,k);
gama     = zeros(N,k-1);
sum_vec  = zeros(3,N);
sum_gama = zeros(N,1); 
t        = 1;
alpha    = zeros(N,k);

% parametrizes set of measurements M_ax with parameters x
for i=1:N
    for j=1:k-1
        gama(i,j)    = abs(x(t));
        vec(:,i,j)   = gama(i,j)*[sin(pi*x(t+1))*cos(2*pi*x(t+2)); sin(pi*x(t+1))*sin(2*pi*x(t+2)); cos(pi*x(t+1))];
        t            = t + 3;
        sum_vec(:,i) = sum_vec(:,i) + vec(:,i,j);
        sum_gama(i)  = sum_gama(i) + gama(i,j);
    end    
    vec(:,i,k) = - sum_vec(:,i);
    gama(i,k)  = norm(vec(:,i,k));
    sum_gama(i) = sum_gama(i) + gama(i,k);
end

for i=1:N
    for j=1:k
        alpha(i,j)    = 2*gama(i,j)/sum_gama(i);
        vec(:,i,j)    = vec(:,i,j)/norm(vec(:,i,j)); 
        M_ax(:,:,i,j) = (1/2)*alpha(i,j)*(eye(dA)+vec(1,i,j)*XX+vec(2,i,j)*YY+vec(3,i,j)*ZZ);
        M_ax(:,:,i,j) = (M_ax(:,:,i,j)+M_ax(:,:,i,j)')/2;
    end
end

% calls SDP to calculate the critical visibility eta
eta = wnr_eta(rho_AB, M_ax);

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

