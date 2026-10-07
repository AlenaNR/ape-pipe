catGr = T.catGr(:);                       % 0 oder 1 pro Person
y = mean(expMat, 2, 'omitnan');            % ein Wert pro Person

% Fehlende Werte und unerwartete Gruppencodes entfernen
valid = isfinite(y) & ismember(catGr, [0 1]);
catGr = catGr(valid);
y = y(valid);

groupNames = ["ADO", "YA"];
g = categorical(catGr, [0 1], groupNames);

% Passend zur bestehenden Projektpalette: Violett und Orange
colors = [0.742 0.681 0.826;
          0.833 0.683 0.528];

figure;
hold on

% Violinen
v = violinplot(g, y);

v.FaceColor = colors(1,:);
v.FaceAlpha = 0.50;

% Einzelpersonen als dicht angeordnete Punkte
swarmchart(g, y, 18, [0.2 0.2 0.2], "filled", ...
    "MarkerFaceAlpha", 0.65, ...
    "MarkerEdgeColor", "none", ...
    "DisplayName", "participant");

% Gruppenmittelwerte als schwarze Rauten
groupMeans = [mean(y(catGr == 0), 'omitnan');
              mean(y(catGr == 1), 'omitnan')];
meanX = categorical(groupNames, groupNames);

scatter(meanX, groupMeans, 75, "k", "d", "filled", ...
    "DisplayName", "Mean");

ylabel("aperiodic exponent");
legend("Location", "best");
box off
hold off