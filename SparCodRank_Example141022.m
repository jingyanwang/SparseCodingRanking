clc
close all
clear all

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load USPS.mat
% 
% X=[];
% Label=[];
% 
% numberPerClass = 50;
% 
% for class = [1:10]
%     [I J] = find(gnd == class);
%     Label = [Label; gnd(I(1:numberPerClass))];
%     X=[X; fea(I(1:numberPerClass),:)];
% end
% 
% X=X';
% Label=Label';
% 
% figure;
% imagesc(X)
% 
% save Data141022 X Label;
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
load Data141022

Input.X=X;
Input.lambda=zeros(1,size(X,2));
Input.lambda(1)=1;

Options.Method='yang';
Options.neighborSize = 5;
Options.beta=1;
Options.delta=1;
Options.gamma=1;


Options.Method='SparseCodingRanking';
Options.alpha = 1;
Options.T=1;
Options.m = 40;

Options.C=1000;

Ouput = SparseCodingRanking141022(Input, Options);