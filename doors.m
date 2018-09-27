% Doors Task
% C. Hassall
% December, 2016
% A collaboration with Greg Hajcak

close all; clear variables;

% Make sure we don't get the same sequence of random numbers each time
rng('shuffle');

% Set to 1 in order to run in windowed mode (command window visible)
% Set to 0 during actual testing
just_testing = 0;
dummy_mode = 0;

if ~just_testing
    Datapixx('Open');
    Datapixx('StopAllSchedules');
    
    % We'll make sure that all the TTL digital outputs are low before we start
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
    
    % Configure digital input system for monitoring button box
    Datapixx('EnableDinDebounce');                          % Debounce button presses
    Datapixx('SetDinLog');                                  % Log button presses to default address
    Datapixx('StartDinLog');                                % Turn on logging
    Datapixx('RegWrRd');
end

% Define control keys
KbName('UnifyKeyNames');
ExitKey = KbName('ESCAPE');
left_kb_key	= KbName('s'); % Left choice
right_kb_key = KbName('k'); % Right choice

% Get participant info
if just_testing
    p_number = '99';
    rundate = datestr(now, 'yyyymmdd-HHMMSS');
    filename = strcat('doors _', rundate, '_', p_number, '.txt');
    sex = 'M';
    age = '21';
    handedness = 'R';
else
    while 1
        clc;
        p_number = input('Enter the participant number:\n','s');  % get the subject name/number
        rundate = datestr(now, 'yyyymmdd-HHMMSS');
        filename = strcat('doors_', rundate, '_', p_number, '.txt');
        checker1 = ~exist(filename,'file');
        checker2 = isnumeric(str2double(p_number)) && ~isnan(str2double(p_number));
        if checker1 && checker2
            break;
        else
            disp('Invalid number, or filename already exists.');
            WaitSecs(1);
        end
    end
    sex = input('Sex (M/F): ','s');
    age = input('Age: ');
    handedness = input('Handedness (L/R): ','s');
end


% Block order (one of 24 permutations, counterbalanced)
p_check = str2double(p_number);
all_perms = perms([1 2 3 4]);
[num_perms,~] = size(all_perms);
this_perm_i = mod(p_check-1,num_perms)+1;
block_types = all_perms(this_perm_i,:);

% Store this participant's info in participant_info.txt
run_line = [num2str(p_number) ', ' datestr(now) ', ' sex, ', ' handedness ', ' num2str(age), num2str(block_types)];
dlmwrite('participant_info.txt',run_line,'delimiter','', '-append');

% Variable for behavioural data
participant_data = [];

% % % Task parameters (Text, Stimuli, and Feedback) % % %

% Task Instructions
questions = 'You will be playing four guessing games.\nFor every win you will receive $0.05, and for every loss you will receive $0.02.\nYou will be paid your total at the end of the experiment.\nYou will receive detailed instructions prior to each game.\nThroughout the task, try to keep your gaze at the center of the display at all times.\nTry to minimize head and eye movements.\n\nPress spacebar to begin.';
block_instructions = {'In this game you will see two doors.\nSelect one of the doors using the mouse.\nOne door leads to a win (green arrow), and the other to a loss (red arrow).\nPlace your hand on the mouse and press any key to begin.',
    'In this game you will see two doors.\nAfter you press the spacebar, the computer will select one of the doors using the mouse.\nOne door leads to a win (green arrow), and the other to a loss (red arrow).\nPlace your hand on the spacebar and press any key to begin.',
    'In this game you will see two doors.\nDo not press any buttons - the computer will automatically select one of the doors using the mouse.\nOne door leads to a win (green arrow), and the other to a loss (red arrow).\nPress any key to begin, then remove your hands from the keyboard.',
    'In this game you will simply receive wins and losses.\nSome trials will result in a win (green arrow), and some trials will result in a loss (red arrow).\nPress any key to begin, then remove your hands from the keyboard.'};

% Task constants
trials_per_block = 60; % 60
num_blocks = 4; % 4
temp = repmat([1 2],1,trials_per_block/2);
outcomes = [Shuffle(temp); Shuffle(temp); Shuffle(temp); Shuffle(temp)];
rest_break_freq = 20; % 20 How often to have a rest break (e.g. every 20 trials)
p_win_1 = 0.5; % p(win) for door 1
p_win_2 = 0.5; % p(win) for door 2

% Task Variables
num_wins = 0; % Total number of wins
num_losses = 0; % Total number of losses

% * * * Graphical Properties * * *
normal_font_size = 20; % Font size for the instructions and block messages
normal_font = 'Arial'; % Font the instructions

% Physical display properties (YOU WILL NEED TO CHANGE THESE)
viewingDistance = 850; % mm, approximately
screenWidth = 598; % mm
screenHeight = 338; % mm
horizontalResolution = 1920; % Pixels
verticalResolution = 1080; % Pixels
horizontalPixelsPerMM = horizontalResolution/screenWidth;
verticalPixelsPerMM = verticalResolution/screenHeight;

% Screen/stim properties
squareDegrees = 2; % Size of a square, in degrees of visual angle
squareMMs = 2 * viewingDistance *tand(squareDegrees/2); % Size of a square, in mm
squareHorizontalPixels = horizontalPixelsPerMM * squareMMs; % Width of square, in pixels
squareVerticalPixels = verticalPixelsPerMM * squareMMs; % Height of square, in pixels
square_thickness = 30; % Not really needed, since we are filling in the squares
square_locations = [-squareHorizontalPixels*1.5 squareHorizontalPixels*1.5]; % Relative to center of the window

% Fixation
fixation_colour = [0 0 0]; % Black
go_colour = [180 180 180]; % Gray
fixation_size = 60; % Font size for the fixation cross

% Text
text_size = 40; % Text stimuli font size (fixation, feedback)
text_colour = [255 255 255]; % Black

% Start of experiment
try
    ShowCursor(1); % Show cursor and make sure it's an arrow
    
    if ~just_testing
        % Hide the cursor and "disable" keyboard
        % Press ctl-c to bring it back
        ListenChar(2);
    end
    
    % Set up a PTB window
    background_colour = [0 0 0];
    if just_testing
        [win, rec] = Screen('OpenWindow', 0, background_colour, [0 0 1000 800],32,2); % Windowed, for testing
    else
        [win, rec] = Screen('OpenWindow', 0, background_colour); % Full screen, for experiment
    end
    
    % How long between frames (needed for animation)
    ifi = Screen('GetFlipInterval', win );
    
    % Load all images
    door_image = imread('./Images/2Doors.bmp');
    door_text = Screen('MakeTexture', win, door_image);
    
    down_image = imread('./Images/DownArrow.jpg');
    down_text = Screen('MakeTexture', win, down_image);
    
    fix_image = imread('./Images/fixation.bmp');
    fix_text = Screen('MakeTexture', win, fix_image);
    
    up_image = imread('./Images/UpArrow.jpg');
    up_text = Screen('MakeTexture', win, up_image);
    
    % Now that a window has been opened, we can define stimuli properties in terms of degrees of visual angle
    [xmid, ymid] = RectCenter(rec); % Midpoint of display
    
    % Pixel (corner) locations for each square
    squares = [xmid-squareHorizontalPixels/2+square_locations(1) ymid-squareVerticalPixels/2 xmid+squareHorizontalPixels/2+square_locations(1) ymid+squareVerticalPixels/2; xmid-squareHorizontalPixels/2+square_locations(2) ymid-squareVerticalPixels/2 xmid+squareHorizontalPixels/2+square_locations(2) ymid+squareVerticalPixels/2;];
    
    % Instructions (what the participant sees first)
    left_button = 's key';
    right_button = 'k key';
    Screen(win,'TextFont',normal_font);
    Screen(win,'TextSize',normal_font_size);
    DrawFormattedText(win, questions,'center', 'center', text_colour,[],[],[],2);
    Screen('Flip',win);
    
    % Wait for space bar press
    KbReleaseWait();
    done_looking = 0;
    while ~done_looking
        [~, ~, keyCode, ~] = KbCheck;
        if strcmp(KbName(keyCode),'space')
            done_looking = 1;
        end
    end
    KbReleaseWait();
    
    for b = 1:num_blocks
        
        this_block = block_types(b);
        
        % New Block Message
        KbReleaseWait();
        Screen(win,'TextFont',normal_font);
        Screen(win,'TextSize',normal_font_size);
        DrawFormattedText(win, block_instructions{this_block} ,'center', 'center', text_colour,[],[],[],2);
        Screen('Flip',win);
        KbPressWait();
        
        % Trial loop
        for t = 1:trials_per_block
            
            if this_block ~= 4
                % Draw doors
                Screen('DrawTexture', win, door_text);
                flipandmark(win,254,dummy_mode);
                % MARKER: Doors
                WaitSecs(0.5);
            end
            
            x_choice = nan;
            y_choice = nan;
            rt_start = GetSecs();
            rt_end = NaN;
            side = NaN;
            outcome = NaN;
            
            % Get Response
            switch this_block
                case 1
                    % Mouse click (pick a door)
                    [x,y,buttons] = GetMouse();
                    while ~any(buttons)
                        [x_choice,y_choice,buttons] = GetMouse();
                    end
                    sendmarker(253,dummy_mode);
                    rt_end = GetSecs() - rt_start;
                case 2
                    KbReleaseWait();
                    KbPressWait();
                    sendmarker(252,dummy_mode);
                    rt_end = GetSecs() - rt_start;
                    % Button press (spacebar) - Computer cursor picks
                    side = randi(2);
                    [x_curr,y_curr,buttons] = GetMouse();
                    y_goal = ymid+5*rand;
                    if side == 1
                        x_goal = xmid - (50+5*rand);
                    else
                        x_goal = xmid + (50+5*rand);
                    end
                    num_frames = (0.3+rand*0.2) / ifi;
                    xstep = (x_goal - x_curr)/num_frames;
                    ystep = (y_goal - y_curr)/num_frames;
                    
                    for f = 1:num_frames
                        SetMouse(x_curr + f*xstep,y_curr + f*ystep);
                        Screen('DrawTexture', win, door_text);
                        Screen('Flip',win);
                    end
                case 3
                    % Nothing - Computer cursor picks
                    side = randi(2);
                    [x_curr,y_curr,buttons] = GetMouse();
                    y_goal = ymid+5*rand;
                    if side == 1
                        x_goal = xmid - (50+5*rand);
                    else
                        x_goal = xmid + (50+5*rand);
                    end
                    num_frames = (0.5+rand*0.2) / ifi;
                    xstep = (x_goal - x_curr)/num_frames;
                    ystep = (y_goal - y_curr)/num_frames;
                    
                    for f = 1:num_frames
                        SetMouse(x_curr + f*xstep,y_curr + f*ystep);
                        Screen('DrawTexture', win, door_text);
                        Screen('Flip',win);
                    end
                    sendmarker(251,dummy_mode);
                    rt_end = GetSecs() - rt_start;
                    
                case 4
                    % Nothing
            end
            
            % Draw crosshairs for 500 ms
            Screen('DrawTexture', win, fix_text);
            flipandmark(win,255,dummy_mode);
            % MARKER: FIXATION CROSS
            WaitSecs(0.5);
            
            % Display the reward for 2 seconds
            outcome = outcomes(b,t);
            if outcome == 1
                num_losses = num_losses + 1;
                Screen('DrawTexture', win, down_text);
            else
                num_wins = num_wins + 1;
                Screen('DrawTexture', win, up_text);
            end
            flipandmark(win,this_block*10+outcome,dummy_mode);
            WaitSecs(2); % Feedback is up for 2000 ms total
            
            this_data_line = [b t this_block side outcome rt_end];
            dlmwrite(filename,this_data_line,'delimiter', '\t', '-append');
            participant_data = [participant_data; this_data_line]; % Not necessary, just an extra copy of the data
            
            % Draw crosshairs for 1500 ms
            Screen('DrawTexture', win, fix_text);
            flipandmark(win,250,dummy_mode);
            % MARKER: FIXATION CROSS
            WaitSecs(1.5);
            
            % Draw "Next outcome"
            Screen(win,'TextFont',normal_font);
            Screen(win,'TextSize',normal_font_size);
            DrawFormattedText(win, 'Next outcome.','center', 'center', text_colour,[],[],[],2);
            flipandmark(win,249,dummy_mode);
            WaitSecs(0.5);
            
            [~, ~, keyCode] = KbCheck();
            if keyCode(ExitKey)
                break;
            end
            
            % Rest break every rest_break_trial trials
            if mod(t,rest_break_freq) == 0 && t ~= trials_per_block
                Screen(win,'TextFont',normal_font);
                Screen(win,'TextSize',normal_font_size);
                DrawFormattedText(win, ['rest break\ntotal: ' num2str(num_wins*0.05 + num_losses*0.02) '\npress any key to continue'],'center', 'center', text_colour,[],[],[],2);
                Screen('Flip',win);
                KbReleaseWait();
                KbPressWait();
            end
        end
        
        %         [~, ~, keyCode] = KbCheck();
        %         if keyCode(ExitKey)
        %             break;
        %         end
        
    end
    
catch e
    % Close the Psychtoolbox window and bring back the cursor and keyboard
    Screen('CloseAll');
    ListenChar(0);
    ShowCursor();
    rethrow(e);
    
    % Close the DataPixx2
    if ~dummy_mode
        Datapixx('Close');
    end
    
    disp(num_wins*0.05 + num_losses*0.02);
end

% Close the Psychtoolbox window and bring back the cursor and keyboard
Screen('CloseAll');
ListenChar(0);
ShowCursor();

% Close the DataPixx2
if ~dummy_mode
    Datapixx('Close');
end

disp(num_wins*0.05 + num_losses*0.02);