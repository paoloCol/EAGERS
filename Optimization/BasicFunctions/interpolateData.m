function interpData = interpolateData(Tfreq,Xi,Xf,Variability)
%This function will interpolate or average to create data points in-line with the specifid frequency in s
%If the resolution of optimization is faster than the stored data it will interpolate and add noise
%If the resolution is larger, it will average the data within each step of the optimization
%% !!current limitation is that all saved data streams have the same timestamp 
%% !!all saved data has constant sampling frequency
global TestData
S = fields(TestData.Demand);
if isfield(TestData,'Hydro')
    H = {'SpillFlow';'InFlow';'OutFlow';'SourceSink';};
else H = [];
end
r = (TestData.Timestamp(2)-TestData.Timestamp(1))*24*3600/Tfreq;% # of points that must be created between datum
lengthTD = length(TestData.Timestamp);
%% create noise vector
if r>0 
    NumSteps = floor((TestData.Timestamp(Xf)-TestData.Timestamp(Xi))*24*3600/Tfreq+1);
    z = randn(NumSteps,1);
    N = zeros(NumSteps,1);
    N(1) = 0;
    N(2) = (rand(1,1)-.5)*Variability; %the value .04 makes the final noise signal peaks = variability with this strategy.
    b= sign(N(2)-N(1));
    c = N(2);
    for n = 3:length(N)
        %if the noise is increasing the probability is such that the noise should continue to increase, but as the noise approaches the peak noise magnitude the probability of switching increases.
        if (c>0 && N(n-1)>0) || (c<0 && N(n-1)<0)
            a = 2*(Variability - abs(N(n-1)))/Variability; %constant 2 = 97.7% probability load changes in same direction, 1.5 = 93.3%, 1 = 84.4%, .5 = 69.1%
        else a = 2;
        end
        if abs(z(n))>.68 %only changes value 50% of the time
             c = b*(z(n)+a); % c is positive if abs(Noise)is increasing, negative if decreasing
             b = sign(c);
             N(n) = N(n-1)+c*Variability; 
        else N(n) = N(n-1);
        end
    end
    Noise = N;% scaled noise to a signal with average magnitude of 1
end

%% take data exactly, or interpolate if necessary
if abs(r-1)<1e-8
    interpData.Timestamp = TestData.Timestamp(Xi:Xf);
    interpData.Temperature = TestData.Temperature(Xi:Xf);
    for j = 1:1:length(S)
        interpData.Demand.(S{j}) = TestData.Demand.(S{j})(Xi:Xf,:);
    end
    for j = 1:1:length(H)
        interpData.Hydro.(H{j}) = TestData.Hydro.(H{j})(Xi:Xf,:);
    end
elseif r<1 %extra datum, average points in between
    NumSteps = floor((TestData.Timestamp(Xf)-TestData.Timestamp(Xi))*24*3600/Tfreq)+1;
    interpData.Timestamp =[];
    interpData.Temperature = zeros(NumSteps,1);
    x1 = Xi;
    for i = 1:1:NumSteps
        x2=nnz(TestData.Timestamp<(TestData.Timestamp(Xi)+i*Tfreq/(24*3600)));
        interpData.Temperature(i) = mean(TestData.Temperature(x1:x2));
        interpData.Timestamp(i) = TestData.Timestamp(x1);
        for j = 1:1:length(S)
            for k = 1:1:length(TestData.Demand.(S{j})(x1,:))
                interpData.Demand.(S{j})(i,k) = mean(TestData.Demand.(S{j})(x1:x2,k));
            end
        end
        for j = 1:1:length(H)
            for k = 1:1:length(TestData.Hydro.(H{j})(x1,:))
                interpData.Hydro.(H{j})(i,k) = mean(TestData.Hydro.(H{j})(x1:x2,k));
            end
        end
        x1=x2+1;
    end
elseif r>1 %interpolate between timesteps
    NumSteps = floor((TestData.Timestamp(Xf)-TestData.Timestamp(Xi))*24*3600/Tfreq+1);
    interpData.Timestamp =zeros(NumSteps,1);
    interpData.Temperature = zeros(NumSteps,1);
    for j = 1:1:length(S)
        interpData.Demand.(S{j}) = zeros(NumSteps,length(TestData.Demand.(S{j})(1,:))); 
    end
    for j = 1:1:length(H)
        interpData.Hydro.(H{j}) = zeros(NumSteps,length(TestData.Hydro.(H{j})(1,:))); 
    end
    x1 = Xi;
    x2 = x1+1;
    for i = 1:1:NumSteps
        interpData.Timestamp(i) = TestData.Timestamp(Xi)+(i-1)*Tfreq/(24*3600);
        r0 = (mod(i-1,r))/r;
        
        if TestData.Timestamp(x2)<=interpData.Timestamp(i)
            x1 = x1+1;
            x2 = min(x1+1,lengthTD);
        end
        interpData.Temperature(i) = (1-r0)*TestData.Temperature(x1) + r0*TestData.Temperature(x2);
        for j = 1:1:length(S)
            interpData.Demand.(S{j})(i,:) = ((1-r0)*TestData.Demand.(S{j})(x1,:)+r0*TestData.Demand.(S{j})(x2,:));
        end
        for j = 1:1:length(H)
            interpData.Hydro.(H{j})(i,:) = ((1-r0)*TestData.Hydro.(H{j})(x1,:)+r0*TestData.Hydro.(H{j})(x2,:));
        end
    end
    for j = 1:1:length(S)
        for k = 1:1:length(TestData.Demand.(S{j})(x1,:))
            interpData.Demand.(S{j})(:,k) = interpData.Demand.(S{j})(:,k).*(1+Noise);%% add noise
        end                   
    end
    interpData.Temperature = interpData.Temperature.*(1+Noise);%% add noise
end 