% compute recall and precision
function [recall, precision, ap] = compute_recall_precision_3DDPM(cls, detections, isfigure)

switch cls
    case 'car'
        cls_data = 'car';
        index_test = 1:200;
end

M = numel(index_test);
path_anno = sprintf('../Annotations/%s', cls_data);
path_image = sprintf('../Images/%s', cls_data);

energy = [];
correct = [];
overlap = [];
count = zeros(M,1);
num = zeros(M,1);
num_pr = 0;
for i = 1:M
    % read ground truth bounding box
    index = index_test(i);
    file_ann = sprintf('%s/%04d.mat', path_anno, index);
    image = load(file_ann);
    object = image.object;
    bbox = object.bbox;
    bbox = [bbox(:,1) bbox(:,2) bbox(:,1)+bbox(:,3) bbox(:,2)+bbox(:,4)];
    count(i) = size(bbox, 1);
    det = zeros(count(i), 1);
    
    % read image
    file_image = sprintf('%s/%04d.jpg', path_image, index);
    I = imread(file_image);    

    example = detections(i);
    num(i) = numel(example.scores);
    % for each predicted bounding box
    for j = 1:num(i)
        num_pr = num_pr + 1;
        energy(num_pr) = example.scores(j);
        % get predicted bounding box
        bbox_pr = example.BB(j,:);
        
        bbox_pr(1) = max(1, bbox_pr(1));
        bbox_pr(2) = max(1, bbox_pr(2));
        bbox_pr(3) = min(bbox_pr(3), size(I,2));
        bbox_pr(4) = min(bbox_pr(4), size(I,1));        
        
        % compute box overlap
        if isempty(bbox) == 0
            o = box_overlap(bbox, bbox_pr);
            [maxo, index] = max(o);
            if maxo >= 0.5 && det(index) == 0
                overlap{num_pr} = index;
                correct(num_pr) = 1;
                det(index) = 1;
            else
                overlap{num_pr} = [];
                correct(num_pr) = 0;        
            end
        else
            overlap{num_pr} = [];
            correct(num_pr) = 0;
        end
    end
end
overlap = overlap';

threshold = unique(sort(energy));
n = numel(threshold);
recall = zeros(n,1);
precision = zeros(n,1);
for i = 1:n
    % compute precision
    num_positive = numel(find(energy >= threshold(i)));
    num_correct = sum(correct(energy >= threshold(i)));
    if num_positive ~= 0
        precision(i) = num_correct / num_positive;
    else
        precision(i) = 0;
    end
    
    % compute recall
    correct_recall = correct;
    correct_recall(energy < threshold(i)) = 0;
    num_correct = 0;
    start = 1;
    for j = 1:M
        for k = 1:count(j)
            for s = start:start+num(j)-1
                if correct_recall(s) == 1 && numel(find(overlap{s} == k)) ~= 0
                    num_correct = num_correct + 1;
                    break;
                end
            end
        end
        start = start + num(j);
    end
    recall(i) = num_correct / sum(count);
end

ap = VOCap(recall(end:-1:1), precision(end:-1:1));
leg{1} = sprintf('Aspectlet (%.4f)', ap);
disp(ap);

if isfigure == 1
    % draw recall-precision curve
    figure(1);hold on;
    plot(recall, precision, 'b', 'LineWidth',3);
    h = legend(leg, 'Location', 'SouthWest');
    set(h,'FontSize',16);
    h = xlabel('Recall');
    set(h,'FontSize',16);
    h = ylabel('Precision');
    set(h,'FontSize',16);
    % tit = sprintf('Average Precision = %.1f', 100*ap);
    tit = sprintf('%s', cls);
    tit(1) = upper(tit(1));
    tit(tit == '_') = ' ';
    h = title(tit);
    set(h,'FontSize',16);
end