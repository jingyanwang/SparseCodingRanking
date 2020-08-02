function Ouput = SparseCodingRanking141022(Input, Options)
    
X=Input.X;
lambda=Input.lambda;

d=size(X,1);
n=size(X,2);
k = Options.neighborSize;
m = Options.m;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmpi(Options.Method,'Yang')    
    y=100*ones(1,n);
    L=zeros(n,n);
    [idx, dist] = knnsearch(X',X','k',Options.neighborSize);
    
    for i=1:n
        X_i{i} = X(:,idx(i,:));
        Phi_i{i} = (X_i{i} *  X_i{i}' + Options.beta*eye(d))^(-1)*X_i{i};
        L_i{i} = ( ( eye(k) -Phi_i{i}' * X_i{i} ) * ( eye(k) -Phi_i{i}' * X_i{i} )' + Options.beta *Phi_i{i}' * Phi_i{i});
        H_i{i} = zeros(n,k);
        
        for l=1:k
            H_i{i}(idx(i,l),l)=1;
        end  
        L=L+ H_i{i}*L_i{i}*H_i{i}';
    end
        
    f = Options.delta * y * diag(lambda) * (Options.gamma*  L + Options.delta* diag(lambda) )^(-1);
    
    figure;
    plot(f)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmpi(Options.Method,'SparseCodingRanking')
    
    alpha = Options.alpha;
    y=100*ones(1,n);
    D = X(:,1:floor(n/m):n);
    D = D(:,1:m);
    S = learn_coefficients(D, X, 0, alpha, zeros(n,n));
%     figure;
%     imagesc(S); 
    
    [idx, dist] = knnsearch(X',X','k',Options.neighborSize);    
    for i=1:n
        H_i{i} = zeros(n,k);        
        for l=1:k
            H_i{i}(idx(i,l),l)=1;            
        end
    end
    
    
    
    C = Options.C;   
        
    for t=1:Options.T
        
        L=zeros(n,n);
        for i=1:n
            S_i{i} = S(:,idx(i,:));
            Phi_i{i} = (S_i{i} *  S_i{i}' + Options.beta*eye(m))^(-1)*S_i{i};
            L_i{i} = ( ( eye(k) -Phi_i{i}' * S_i{i} ) * ( eye(k) -Phi_i{i}' * S_i{i} )' + Options.beta *Phi_i{i}' * Phi_i{i});
            L=L+ H_i{i}*L_i{i}*H_i{i}';
        end
        f = Options.delta * y * diag(lambda) * (Options.gamma*  L + Options.delta* diag(lambda) )^(-1);
        
        for i=1:n
            f_i{i} = f(idx(i,:));
            w_i{i} = Phi_i{i} * f_i{i}';
        end
        
        
  
    end
    figure;
    plot(f)
end

Ouput.f = f;
end









%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Sout = learn_coefficients(B, X, alpha, gamma, L, Sinit)
% The feature-sign search algorithm
% L1-regularized least squares problem solver
%
% This code solves the following problem:
% 
%   minimize_s 0.5*(||xi-B*si||^2 + alpha*si'si + 2*alpha*si(sigma(Lijsj)) +
%   gamma*||si||_1 
% X : data matrix
% B : basis matrix
% Sinit : initial coefficient matrix 
%
% References:
% [1] Miao Zheng, Jiajun Bu, Chun Chen, Can Wang, Lijun Zhang, Guang Qiu, Deng Cai. 
% "Graph Regularized Sparse Coding for Image Representation",
% IEEE Transactions on Image Processing, Vol. 20, No. 5, pp. 1327-1336, 2011. 
%
% Version1.0 -- Nov/2009
% Version2.0 -- Jan/2012
% Written by Miao Zheng <cauthy AT zju.edu.cn>
%
warning('off', 'MATLAB:divideByZero');

use_Sinit= false;
if exist('Sinit', 'var')
    use_Sinit= true;
end

Sout= zeros(size(B,2), size(X,2));
BtB = B'*B;
BtX = B'*X;

rankB = rank(BtB);
% rankB = min(size(B,1)-10, size(B,2)-10);

for i=1:size(X,2)
%     if mod(i, 100)==0, fprintf('.'); end %fprintf(1, 'l1ls_featuresign: %d/%d\r', i, size(X,2)); end
    if use_Sinit
        idx1 = find(Sinit(:,i)~=0);
        maxn = min(length(idx1), rankB);
        sinit = zeros(size(Sinit(:,i)));
        sinit(idx1(1:maxn)) =  Sinit(idx1(1:maxn), i);
        a = sum(sum(Sinit,2)==0);
        S = [Sout(:,1:i),Sinit(:,(i+1):size(X,2))];
        [Sout(:,i), fobj]= ls_featuresign_sub (B, S, X(:,i), BtB, BtX(:,i), L, i, alpha, gamma, sinit);
    else
        [Sout(:,i), fobj]= ls_featuresign_sub (B, Sout, X(:,i), BtB, BtX(:,i), L, i, alpha, gamma);
    end
end

% fprintf(1, '\n');

warning('on', 'MATLAB:divideByZero');

return;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function [s, fobj] = ls_featuresign_sub (B, S, x, BtB, Btx, L, i, alpha, gamma, sinit)

[N,M] = size(B);

rankB = rank(BtB);
% rankB = min(size(B,1)-10, size(B,2)-10);

% Step 1: Initialize
usesinit = false;
if ~exist('sinit', 'var') || isempty(sinit)
    sinit= [];
    s= sparse(zeros(M,1));
    theta= sparse(zeros(M,1));
    act= sparse(zeros(M,1));
    allowZero = false;
else
    % sinit = [];
    s= sparse(sinit);
    theta= sparse(sign(s));
    act= sparse(abs(theta));
    usesinit = true;
    allowZero = true;
end


L_new = L(:,i);
L_new(i) = 0;
P = S*L_new;

fobj = fobj_featuresign(s, B, x, BtB, Btx, P, L, i, alpha, gamma);

ITERMAX=1000;
optimality1=false;
for iter=1:ITERMAX
    % check optimality0
    act_indx0 = find(act == 0);
    
    grad = BtB*sparse(s)+alpha*L(i,i)*sparse(s)+alpha*P - Btx;
    theta = sign(s);

    optimality0= false;
    % Step 2
    [mx,indx] = max (abs(grad(act_indx0)));

    if ~isempty(mx) && (mx >= gamma) && (iter>1 || ~usesinit)
        act(act_indx0(indx)) = 1;
        theta(act_indx0(indx)) = -sign(grad(act_indx0(indx)));
        usesinit= false;
    else
        optimality0= true;
        if optimality1
            break;
        end
    end
    act_indx1 = find(act == 1);

    if length(act_indx1)>rankB
        warning('sparsity penalty is too small: too many coefficients are activated');
        return;
    end

    if isempty(act_indx1) %length(act_indx1)==0
        % if ~assert(max(abs(s))==0), save(fname_debug, 'B', 'x', 'gamma', 'sinit'); error('error'); end
        if allowZero, allowZero= false; continue, end
        return;
    end

    % if ~assert(length(act_indx1) == length(find(act==1))), save(fname_debug, 'B', 'x', 'gamma', 'sinit'); error('error'); end
    k=0;
    while 1
        k=k+1;

        if k>ITERMAX
%             warning('Maximum number of iteration reached. The solution may not be optimal');
            % save(fname_debug, 'B', 'x', 'gamma', 'sinit');
            return;
        end

        if isempty(act_indx1) % length(act_indx1)==0
            % if ~assert(max(abs(s))==0), save(fname_debug, 'B', 'x', 'gamma', 'sinit'); error('error'); end
            if allowZero, allowZero= false; break, end
            return;
        end

        % Step 3: feature-sign step
        [s, theta, act, act_indx1, optimality1, lsearch, fobj] = compute_FS_step (s, B, x, BtB, Btx, P, L, i, theta, act, act_indx1, alpha, gamma);

        % Step 4: check optimality condition 1
        if optimality1 break; end;
        if lsearch >0 continue; end;

    end
end

if iter >= ITERMAX
    warning('Maximum number of iteration reached. The solution may not be optimal');
    % save(fname_debug, 'B', 'x', 'gamma', 'sinit');
end

if 0  % check if optimality
    act_indx1 = find(act==1);
    grad =  BtB*sparse(s)+alpha*L(i,i)*sparse(s)+alpha*P - Btx;
    norm(grad(act_indx1) + gamma.*sign(s(act_indx1)),'inf')
    find(abs(grad(setdiff(1:M, act_indx1)))>gamma)
end

fobj = fobj_featuresign(s, B, x, BtB, Btx, P, L, i, alpha, gamma);

return;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [s, theta, act, act_indx1, optimality1, lsearch, fobj] = compute_FS_step (s, B, x, BtB, Btx, P, L, idx, theta, act, act_indx1, alpha, gamma)

s2 = s(act_indx1);
% B2 = B(:, act_indx1);
BtB2 = BtB(act_indx1, act_indx1);
theta2 = theta(act_indx1);


a = L(idx,idx)*alpha*ones(size(act_indx1));
%a = L(idx,idx)*alpha*eye(size(act_indx1,1));
% call matlab optimization solver..
s_new = (BtB2+diag(a)) \ ( Btx(act_indx1) - gamma.*theta2 -alpha*P(act_indx1)); % RR

% opts.POSDEF=true; opts.SYM=true; % RR
% s_new = linsolve(BtB2, ( Btx(act_indx1) - gamma.*theta2 ), opts); % RR
optimality1= false;
if (sign(s_new) == sign(s2)) 
    optimality1= true;
    s(act_indx1) = s_new;
    fobj = 0; 
    %fobj = fobj_featuresign(s, B, x, BtB, Btx, P, L, idx, alpha, gamma);
    lsearch = 1;
    return; 
end

% do line search: s -> s_new
progress = (0 - s2)./(s_new - s2);
lsearch=0;

a= 0.5*sum((B(:,act_indx1)*(s_new-s2)).^2)+0.5*alpha*L(idx,idx)*(s_new-s2)'*(s_new-s2);
b= (s_new-s2)'*(alpha*P(act_indx1)-Btx(act_indx1)) + (s2'*BtB2+ alpha*L(idx,idx)*s2')*(s_new-s2);

fobj_lsearch = gamma*sum(abs(s2));
[sort_lsearch, ix_lsearch] = sort([progress',1]);
remove_idx=[];
for i = 1:length(sort_lsearch)
    t = sort_lsearch(i); if t<=0 || t>1 continue; end
    s_temp= s2+ (s_new- s2).*t;
    fobj_temp = a*t^2 + b*t + gamma*sum(abs(s_temp));
    if fobj_temp < fobj_lsearch
        fobj_lsearch = fobj_temp;
        lsearch = t;
        if t<1  remove_idx = [remove_idx ix_lsearch(i)]; end % remove_idx can be more than two..
    elseif fobj_temp > fobj_lsearch
        break;
    else
        if (sum(s2==0)) == 0
            lsearch = t;
            fobj_lsearch = fobj_temp;
            if t<1  remove_idx = [remove_idx ix_lsearch(i)]; end % remove_idx can be more than two..
        end
    end
end

% if ~assert(lsearch >=0 && lsearch <=1), save(fname_debug, 'B', 'x', 'gamma', 'sinit'); error('error'); end

if lsearch >0
    % update s
    s_new = s2 + (s_new - s2).*lsearch;
    s(act_indx1) = s_new;
    theta(act_indx1) = sign(s_new);  % this is not clear...
end

% if s encounters zero along the line search, then remove it from
% active set
if lsearch<1 && lsearch>0
    %remove_idx = find(s(act_indx1)==0);
    remove_idx = find(abs(s(act_indx1)) < eps);
    s(act_indx1(remove_idx))=0;

    theta(act_indx1(remove_idx))=0;
    act(act_indx1(remove_idx))=0;
    act_indx1(remove_idx)=[];
end
%fobj_new = 0; 
fobj_new = fobj_featuresign(s, B, x, BtB, Btx, P, L, idx, alpha, gamma);

fobj = fobj_new;

return;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [f, g] = fobj_featuresign(s, B, x, BtB, Btx, P, L, i, alpha, gamma)

f= 0.5*(norm(x-B*s)^2+alpha*L(i,i).*(s'*(s+2*P)));
f= f+ gamma*norm(s,1);

if nargout >1
    g = BtB*s+alpha*L(i,i)*s+alpha*P - Btx;
    g= g+ gamma*sign(s);
end

return;
end
%%%%%%%%%%%%%%%%%%%%%

function B = learn_basis(X, S, l2norm, Binit)
% Learning basis using Lagrange dual (with basis normalization)
%
% This code solves the following problem:
% 
%    minimize_B   0.5*||X - B*S||^2
%    subject to   ||B(:,j)||_2 <= l2norm, forall j=1...size(S,1)
% 
% The detail of the algorithm is described in the following paper:
% 'Efficient Sparse Codig Algorithms', Honglak Lee, Alexis Battle, Rajat Raina, Andrew Y. Ng, 
% Advances in Neural Information Processing Systems (NIPS) 19, 2007
%
% Written by Honglak Lee <hllee@cs.stanford.edu>
% Copyright 2007 by Honglak Lee, Alexis Battle, Rajat Raina, and Andrew Y. Ng

L = size(X,1);
N = size(X,2);
M = size(S, 1);

% tic
SSt = S*S';
XSt = X*S';

if exist('Binit', 'var')
    dual_lambda = diag(Binit\XSt - SSt);
else
    dual_lambda = 10*abs(rand(M,1)); % any arbitrary initialization should be ok.
end

c = l2norm^2;
trXXt = sum(sum(X.^2));

lb=zeros(size(dual_lambda));
options = optimset('GradObj','on', 'Hessian','on','Display','off');
%  options = optimset('GradObj','on', 'Hessian','on', 'TolFun', 1e-7);

[x, fval, exitflag, output] = fmincon(@(x) fobj_basis_dual(x, SSt, XSt, X, c, trXXt), dual_lambda, [], [], [], [], lb, [], [], options);
% output.iterations
fval_opt = -0.5*N*fval;
dual_lambda= x;

Bt = (SSt+diag(dual_lambda)) \ XSt';
B_dual= Bt';
fobjective_dual = fval_opt;


B= B_dual;
% fobjective = fobjective_dual;
% toc

return;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [f,g,H] = fobj_basis_dual(dual_lambda, SSt, XSt, X, c, trXXt)
% Compute the objective function value at x
L= size(XSt,1);
M= length(dual_lambda);

SSt_inv = inv(SSt + diag(dual_lambda));

% trXXt = sum(sum(X.^2));
if L>M
    % (M*M)*((M*L)*(L*M)) => MLM + MMM = O(M^2(M+L))
    f = -trace(SSt_inv*(XSt'*XSt))+trXXt-c*sum(dual_lambda);
    
else
    % (L*M)*(M*M)*(M*L) => LMM + LML = O(LM(M+L))
    f = -trace(XSt*SSt_inv*XSt')+trXXt-c*sum(dual_lambda);
end
f= -f;

if nargout > 1   % fun called with two output arguments
    % Gradient of the function evaluated at x
    g = zeros(M,1);
    temp = XSt*SSt_inv;
    g = sum(temp.^2) - c;
    g= -g;
    
    
    if nargout > 2
        % Hessian evaluated at x
        % H = -2.*((SSt_inv*XSt'*XSt*SSt_inv).*SSt_inv);
        H = -2.*((temp'*temp).*SSt_inv);
        H = -H;
    end
end

return
end

