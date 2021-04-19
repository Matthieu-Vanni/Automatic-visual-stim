function TrialList = CreateTrialList(SF,TF,C,angDir,nTrials)
    
    vectors = {SF, TF, C, angDir}; %// input data: cell array of vectors
    n = numel(vectors); %// number of vectors
    combs = cell(1,n); %// pre-define to generate comma-separated list
    [combs{end:-1:1}] = ndgrid(vectors{end:-1:1}); %// the reverse order in these two
    %// comma-separated lists is needed to produce the rows of the result matrix in
    %// lexicographical order 
    combs = cat(n+1, combs{:}); %// concat the n n-dim arrays along dimension n+1
    combs = reshape(combs,[],n); %// reshape to obtain desired matrix
    
%     blank = [combs(1,1) , 0, 0, 0]; % Here, we insert a blank in the stimulus list.
%     combs = vertcat(blank, combs);
%     
    TrialList = zeros(size(combs,1)*nTrials, size(combs,2));
    a = 1; % Index to be used in for loop. 
    combLength = size(combs,1);
    for ind = 1:nTrials
        idx = randperm(combLength);
        TrialList(a:a+combLength-1, :) = combs(idx,:);
        a = a + combLength;
    end 

  end 