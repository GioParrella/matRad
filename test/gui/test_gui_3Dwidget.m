function test_suite = test_gui_3Dwidget
%The output should always be test_suite, and the function name the same as
%your file name

%% Header
% The header is required to be in this format for automatic test collection
% by MOxUnit

%To collect all tests defined below, this is needed in newer Matlab
%versions. test_functions will collect function handles to below test
%functions
test_functions=localfunctions(); 

% This will initialize the test suite, i.e., take the functions from
% test_functions, check if they contain "test", convert them into a MOxUnit
% Test Case, and add them to the test-runner
initTestSuite;

%% Custom Tests
% Tests use assert*-like Functions to check outputs etc:
% assertTrue(a) - a is true
% assertFalse(a) - a is false
% assertEqual(a,b) - a and be are equal (isequal)
% assertElementsAlmostEqual(a,b) - numerical test for all vector / matrix elements. Has Additional arguments for absolute / relative tolerance 
% assertVectorsAlmostEqual(a,b) - numerical test using vector norm
% assertExceptionThrown(f,id) - test if exception of id is thrown. Take care of Octave issues with exception id (or don't provide id)
% Check MOxUnit for more information or look at other tests

function test_3DWidget_constructor
    % Test the constructor of matRad_3DWidget class
    h = matRad_3DWidget();
    assertTrue(isa(h, 'matRad_3DWidget'));
    assertTrue(isa(h, 'matRad_ViewingWidget'));
    assertTrue(isa(h, 'matRad_Widget'));
    delete(h);

    p = uipanel();
    h = matRad_3DWidget(p);
    assertTrue(isa(h, 'matRad_3DWidget'));
    assertTrue(isa(h, 'matRad_ViewingWidget'));
    assertTrue(isa(h, 'matRad_Widget'));
    delete(h);
    close(get(p,'Parent'));

function test_3Dwidget_constructWithData
    evalin('base','load TG119.mat');
    h = matRad_3DWidget();
    try
        assertTrue(isa(h, 'matRad_3DWidget'));
    assertTrue(isa(h, 'matRad_ViewingWidget'));
    assertTrue(isa(h, 'matRad_Widget'));
        delete(h);
    catch ME
        evalin('base','clear ct cst pln');
        rethrow(ME);
    end
    evalin('base','clear ct cst pln');
    

%TODO: Test Buttons / visibility depending on data