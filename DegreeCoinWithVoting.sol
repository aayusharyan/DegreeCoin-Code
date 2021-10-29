// SPDX-License-Identifier: GPL-3.0
/*
    DegreeCoin       - A decentralized Degree equivalency tool.
    Deployer Address - 0xXXXX
    Deployed Network - Ropsten Test Network

    Limitation
     - This application can only handle 2^255 unique degrees before collision.
     - Similarly, each university can have upto 2^255 blacklists each for other universities as well as courseTemplates.
     - This technical blocker is because of situations when indexed search needs to be done, so when a match is not found, it should return -1.
     - That cannot be done if we use uint256, therefore switching to int which can handle negative numbers as well.
*/
pragma solidity >=0.7.0 <0.9.0;

contract DegreeCoin {
    
    /*
     * Template of a course used for global standardization, each course of a university will map to one of these templates.
     * Universities can decide whether to trust a template or not.
     * However, if they are mapping their degree to a template, then they are automatically trusting that template.
     * Adding a new template means a new global standard of degree is developed. This requires voting.
     * 
     * @prop createdBy          - Address of the university which suggested to create this.
     * @prop name               - Name of the course (Standardized - English). For local translation, it will be done in frontend.
     * @prop description        - Description of what this standardization is about and exact content this covers.
     * @prop duration           - Number of months it takes to complete.
     * @prop isVoted            - Mapping of addresses which have voted to prevent from double voting. This maps the address to the timestamp when voted.
     * @prop yesCount           - The count of addresses that have voted yes.
     * @prop noCount            - The count of addresses whta have voted no.
     * @prop votingEndTimestamp - This is the UNIX Timestamp (seconds) beyond which voting is not allowed.
     * @prop isVerified         - Decides whether this is a verified courseTemplate or not.
     */
    struct CourseTemplate {
        address createdBy;
        string name;
        string description;
        uint8 duration;
        mapping(address => uint256) isVoted;
        uint256 yesCount;
        uint256 noCount;
        uint256 votingEndTimestamp;
        bool isVerified;
    }

    /*
     * Template of a course used for global standardization,stripped of all the voting information.
     * Only used for returning to the frontend of the platform.
     * Any data using this Struct is assumed to be of a verified courseTemplate
     * 
     * @prop name        - Name of the course (Standardized - English). For local translation, it will be done in frontend.
     * @prop description - Description of what this standardization is about and exact content this covers.
     * @prop duration    - Number of months it takes to complete.
     */
    struct CourseTemplatePublic {
        string name;
        string description;
        uint8 duration;
    }

    /*
     * Course a university is offering. Considering different language and different education standards.
     * Each of these courses will map to one template which will be the equivalency of that course globally.
     * 
     * @prop name        - Name of the course.
     * @prop description - Information on what is offered in this course.
     * @prop duration    - Number of months it takes to complete the course.
     * @prop equivalency - Equivalen standardized courseTemplate to this course.
     */
    struct Course {
        string name;
        string description;
        uint8 duration;
        uint256 equivalency;
    }
    
    /*
     * Degree which is issued to a student by the university.
     * Each of these degrees are unique and thus can be considered as an NFT.
     * This will contain the information about performance of the student and related comments.
     * 
     * @prop issuer   - Address of the issuing university.
     * @prop cgpa     - CGPA of the student (from 00.00/0000 to 10.00/1000).
     * @prop grade    - Grade of student written in words. (For example, "First Class with Distinction").
     * @prop issuedAt - UNIX Timestamp (seconds) when the degree was issued.
     * @prop courseID - Reference to the ID of the course for which this degree is issued.
     * @prop comments - Additional comments that can be added while issuing the degree. (For example, "Exceptional Work").
     */
    struct Degree {
        address issuer;
        uint16 cgpa;
        string  grade;
        uint256 issuedAt;
        uint256 courseID;
        string comments;
    }

    /*
     * Profile of each Student.
     * 
     * @prop degreeCount - Total number of degrees held by a student. [Additional Feature, for storing metadata].
     * @prop degrees     - List of refences to each of the individual degree issued to that student.
     */
    struct Student {
        uint256 degreeCount;
        Degree[] degrees;
    }

    /*
     * Profile of each University.
     * 
     * @prop name                       - Name of the university. (It is not mandatory to have, provided we can be pseudo-anonymous)
     * @prop invitedBy                  - The address of university which invited this university.
     * @prop establishedAt              - UNIX Timestamp (seconds) when the university was established. (Added to this application)
     * @prop blacklistedUniversities    - List of universities that are blacklisted.
     * @prop blacklistedCourseTemplates - List of courseTemplates whose equivalency is not considered valid.
     * @prop courses                    - List of courses offered.
     */
    struct University {
        string name;
        address invitedBy;
        uint256 establishedAt;
        address[] blacklistedUniversities; 
        uint256[] blacklistedCourseTemplates;
        Course[] courses;
    }

    /*
     * List of available students and universities on the application.
     * This is mapped with the address of the account holder.
     * Each array maps to a struct defining the data structure of that Student/University.
     */
    mapping (address => Student) private students;
    mapping (address => University) private universities;

    /*
     * List of available courseTemplates on the application.
     * This should have been an array, but needs to be a mapping because the courseTemplate contains mapping.
     * That is a technical limitation.
     * Since it is not possible to loop on a mapping and also not possible to get the length.
     * Therefore, using a counter to keep the length of courseTemplates used updated.
     */
    mapping(uint256 => CourseTemplate) private courseTemplates;
    uint256 private courseTemplatesCount;

    /*
     * Some statistics of the application. (Number of Degrees issued, Number of universities registered, Number of Students registered)
     * This data does not add any useful functionality but helps to get a broad picture of usage of this contract.
     * Even though these counters are public, they can only be read publicly. They cannot be overwritten by any public method.
     * They can only be overwritten from within this contract where it should update.
     */
    uint256 public issuedDegreeCount;
    uint256 public universityCount;
    uint256 public studentCount;

    uint8 public constant ACCOUNT_TYPE_UNIVERSITY = 101;
    uint8 public constant ACCOUNT_TYPE_STUDENT    = 102;

    //Address of the contract owner. This is initialized when the contract is deployed.
    address public owner;
    

    /*
     * Constructor of the Contract. This is executed only once.
     * The deployer of the contract is set as the ownser who is the first university in the network.
     * The owner also has a superpower to create courseTemplate without the need of voting.
     * This might create a trust requirement for the owner to be honest, but the owner can be a multi-sig wallet.
     * Using a multi-sig wallet will reduce the fear of the owner maliciously changing anything. As majority has to agree for a change.
     * Deployer address written in the top comment should match with the owner in order to verify that this is the genuine copy of contract.
     * Added a dummy 
     *
     * @param _name - Name of the contract owner
     */
    constructor(string memory _name) {
        owner = msg.sender;
        University storage university = universities[owner];
        university.name = _name;
        university.invitedBy = address(this);
        university.establishedAt = block.timestamp;

        courseTemplates[0].name = "Dummy Degree - INVALID";
        courseTemplates[0].isVerified = false;
    }

    /*
     * Invite a university for registration on the application.
     * 
     * @param university - Address of the university to be invited.
     * @return address   - Address of the university which has been invited.
     * @validation 
     * - The inviter should be a valid university.
     * - The invited university should not be already Registered.
     */
    function inviteUniversity(address university) onlyUniversity() external returns(address) {
        require(universities[university].establishedAt == 0, "University already registered");
        universities[university].invitedBy = msg.sender;

        return university;

    }

    /*
     * Register a University on the application which already has an invitation.
     * 
     * @param _name    - Name of the University.
     * @return address - Address of the university which has been registered.
     * @validation 
     * - The university should not be already registered.
     * - The address should not belong to a student.
     * - The university needs to be invited by another valid university before attempting registration.
     */
    function registerUniversity(string calldata _name) external returns(address) {
        require(!isValidUniversity(), "The university is already registered");
        require(students[msg.sender].degreeCount == 0, "The Address is of a student, cannot register as a University");
        address invitedBy = universities[msg.sender].invitedBy;
        require(address(invitedBy) != address(0), "Only invited universities can be registered");
        require(isValidUniversity(invitedBy), "The invitation is invalid, please re-request invitation");

        universities[msg.sender].name = _name;
        universities[msg.sender].establishedAt = block.timestamp;

        incrementUniversityCount();
        return msg.sender;
    }

    /*
     * Update name of a university.
     * 
     * @param _name   - Name of the University.
     * @return string - Updated name of the University.
     */
    function updateUniversityName(string calldata _name) external returns(string calldata) {
        universities[msg.sender].name = _name;
        return _name;
    }

    /*
     * Add a blacklisted university to the list.
     * 
     * @param blacklistedUniversity - Address of the University.
     * @return address[]            - Updated list of blacklisted Universities.
     * @validation
     * - The university needs to be registered.
     * - The number of blacklists added has to be less than 2^255.
     */
    function addBlacklistedUniversity(address blacklistedUniversity) onlyUniversity() external returns(address[] memory) {
        require(universities[msg.sender].blacklistedUniversities.length <= uint256(2**255), "Maximum number of blacklisted universities reached");
        if(!isBlackListedUniversity(blacklistedUniversity)) {
            universities[msg.sender].blacklistedUniversities.push(blacklistedUniversity);
        }
        return universities[msg.sender].blacklistedUniversities;
    }

    /*
     * Remove a blacklisted university from the list.
     * 
     * @param blacklistedUniversity - Address of the University.
     * @return address[]            - Updated list of blacklisted Universities.
     * @validation
     * - The university needs to be registered.
     * - The university to be removed needs to be in the blacklist.
     */
    function removeBlacklistedUniversity(address blacklistedUniversity) onlyUniversity() external returns(address[] memory) {
        int blacklistedUniversityIndex = getBlackListedUniversityIndex(blacklistedUniversity);
        require(blacklistedUniversityIndex >= 0, "University is not in Blacklist");

        //Oh Daamn! Naming like Java Classes, lol
        universities[msg.sender].blacklistedUniversities[uint256(blacklistedUniversityIndex)] = universities[msg.sender].blacklistedUniversities[universities[msg.sender].blacklistedUniversities.length - 1];
        universities[msg.sender].blacklistedUniversities.pop();

        return universities[msg.sender].blacklistedUniversities;
    }

    /*
     * Check whether the university is blacklisted or not.
     * 
     * @param university - Address of the University.
     * @return bool      - Whether the university is blacklisted or not.
     */
    function isBlackListedUniversity(address university) public view returns(bool) {
        if(getBlackListedUniversityIndex(university) > -1) {
            return true;
        }
        return false;
    }

    /*
     * Get index of the blacklisted university.
     * This is a private method, that means it can only be called from within this Contract.
     * 
     * @param university - Address of the University.
     * @return int       - Index of the blacklisted university, -1 if not found.
     */
    function getBlackListedUniversityIndex(address university) private view returns(int) {
        address[] memory blacklistedUniversities = universities[msg.sender].blacklistedUniversities;
        for (uint256 i=0; i<blacklistedUniversities.length; i++) {
            if(blacklistedUniversities[i] == university) {
                return int(i);
            }
        }
        return -1;
    }

    /*
     * Add a blacklisted courseTemplate  to the list.
     * 
     * @param courseTemplateID - ID of the courseTemplate.
     * @return uint256[]       - Updated list of blacklisted courseTemplates.
     * @validation
     * - The university needs to be registered.
     * - Upto 2^255 blacklisted courses can be added.
     */
    function addBlackListedCourseTemplate(uint256 courseTemplateID) onlyUniversity() external returns(uint256[] memory) {
        require(universities[msg.sender].blacklistedCourseTemplates.length < uint256(2**255), "Upto 2^255 blacklisted courses can be added");
        if(!isBlackListedCourseTemplate(courseTemplateID)) {
            universities[msg.sender].blacklistedCourseTemplates.push(courseTemplateID);
        }
        return universities[msg.sender].blacklistedCourseTemplates;
    }

    /*
     * Remove a blacklisted courseTemplate from the list.
     * 
     * @param courseTemplateID - ID of the courseTemplate.
     * @return uint256[]       - Updated list of blacklisted courseTemplates.
     * @validation
     * - The university needs to be registered.
     * - The courseTemplate to be removed needs to be in the blacklist.
     */
    function removeBlackListedCourseTemplate(uint256 courseTemplateID) onlyUniversity() external returns(uint256[] memory) {
        int blacklistedCourseTemplateIndex = getBlackListedCourseTemplateIndex(courseTemplateID);
        require(blacklistedCourseTemplateIndex > -1, "Course Template is not blacklisted");

        //Another one.
        universities[msg.sender].blacklistedCourseTemplates[uint256(blacklistedCourseTemplateIndex)] = universities[msg.sender].blacklistedCourseTemplates[universities[msg.sender].blacklistedCourseTemplates.length - 1];
        universities[msg.sender].blacklistedCourseTemplates.pop();

        return universities[msg.sender].blacklistedCourseTemplates;
    }

    /*
     * Check whether the courseTemplate is blacklisted or not.
     * 
     * @param courseTemplateID - ID of the courseTemplate.
     * @return bool            - Whether the courseTemplate is blacklisted or not.
     */
    function isBlackListedCourseTemplate(uint256 courseTemplateID) public view returns(bool) {
        if(getBlackListedCourseTemplateIndex(courseTemplateID) > -1) {
            return true;
        }
        return false;
    }

    /*
     * Get index of the blacklisted courseTemplate.
     * This is a private method, that means it can only be called from within this Contract.
     * 
     * @param courseTemplateID  - ID of the courseTemplate.
     * @return int              - Index of the blacklisted courseTemplate, -1 if not found.
     */
    function getBlackListedCourseTemplateIndex(uint256 courseTemplateID) private view returns(int) {
        uint256[] memory blacklistedCourseTemplates = universities[msg.sender].blacklistedCourseTemplates;
        for (uint256 i=0; i<blacklistedCourseTemplates.length; i++) {
            if(blacklistedCourseTemplates[i] == courseTemplateID) {
                return int(i);
            }
        }
        return -1;
    }
    
    /*
     * Get list of blacklisted courseTemplates of a university.
     * 
     * @return uint256[] - List of blacklisted courseTemplate indices (Global)
     */
    function getBlacklistedCourseTemplates() view external returns(uint256[] memory) {
        return universities[msg.sender].blacklistedCourseTemplates;
    }

    /*
     * Register course by a university. The course needs to be mapped to a valid non blacklisted equivalent courseTemplate.
     *
     * @param name        - Name of the course.
     * @param description - Description of the content offered in the course.
     * @param duration    - Duration of course in months.
     * @param equivalency - Global identifier of equivalent courseTemplate.
     * @return string     - Name of the course registered.
     * @validation
     * - Issuing university should be a valid university.
     * - Name of the course cannot be empty.
     * - Duration of the course cannot be 0.
     * - Equivalency needs to map to a valid courseTemplate.
     * - Equivalent courseTemplate should not be blacklisted.
     * - Upto 2^255 courses can be registered by a university.
     */
    function registerCourse(string calldata name, string calldata description, uint8 duration, uint256 equivalency) onlyUniversity() external returns(string calldata) {
        require(universities[msg.sender].courses.length < uint256(2**255), "Maximum number of registered courses reached");
        require(bytes(name).length > 0, "Course name cannot be empty");
        require(duration > 0, "Duration of course should be more than 0");
        require(courseTemplates[equivalency].isVerified, "The equivalent courseTemplate should be valid");
        require(!isBlackListedCourseTemplate(equivalency), "The equivalent courseTemplate cannot be blacklisted");
        
        Course memory course = Course(name, description, duration, equivalency);
        universities[msg.sender].courses.push(course);
        return name;
    }

    /*
     * Issue degree to a Student.
     * 
     * @param studentAddr - Address of the Student whom to issue the degree.
     * @param courseID    - ID of the course for which the degree is being issued.
     * @param cgpa        - CGPA marks being awarded.
     * @param grade       - Grade being awarded.
     * @param comments    - Any additional comments if needed to be added to the degree.
     * @return bool       - True, only if the issuance was successful.
     * @validation
     * - University should be registered.
     * - CGPA can only be between 0000 and 1000 (both included).
     * - Issuing degree should have an equivalency connected.
     */
    function issueDegree(address studentAddr, uint256 courseID, uint16 cgpa, string memory grade, string memory comments) external returns(bool) {
        require(universities[msg.sender].establishedAt > 0, "The university is not registered");
        require(((cgpa >= 0) && (cgpa <= 1000)), "CGPA has to be between 0000 and 1000");

        University memory university = universities[msg.sender];
        require((university.courses[courseID].equivalency > 0), "The degree is not valid, it should have some equivalency");

        uint256 issuedAt = block.timestamp;
        Degree memory degree = Degree(msg.sender, cgpa, grade, issuedAt, courseID, comments);
        Student storage student = students[studentAddr];

        student.degrees.push(degree);      
        student.degreeCount++;

        incrementIssuedDegreeCount();
        if(student.degreeCount == 1) {
            incrementStudentCount();
        }

        return true;
    }

    /*
     * Get specific Degree (identified by intex) of a specific student address.
     * This will be accessed by the university when they want to evaluate a certain degree.
     * Therefore, this will also return equivalent course ID offered by the university.
     * If the access is done by not a university, then equivalent course will return -1.
     * This is the primary function that can be used by companies and other universities to evaluate anyone's degree.
     *
     * @param student   - Address of the Student whose degree needs to be validated.
     * @param degreeID  - Index of the degree that needs to be fetched.
     * @return Degree   - Degree of the Student.
     * @return int      - Equivalent course which is offered by this university. -1 if there is no equivalent course or not a valid university.
     * @return bool     - Boolean whether the course has been blacklisted or not.
     * @return bool     - Boolean on whether the issuing university has been blacklisted or not.
     * @validation
     * - degreeID should be a positive index.
     * - The student should have atleast 1 degree issued.
     * - The degreeID should be within bounds of the degree
     */
    function getDegree(address student, int degreeID) public view returns(Degree memory degree, int equivalentCourseID, bool isCourseBlacklisted, bool isUniversityBlacklisted) {
        require(degreeID > 0, "Value of degreeID cannot be negative");
        require(students[student].degrees.length > 0, "The student does not have any degree issued");
        require(students[student].degrees.length > uint256(degreeID), "The DegreeID is out of bounds");
        degree = students[student].degrees[uint256(degreeID)];
        equivalentCourseID = -1;
        isCourseBlacklisted = false;
        isUniversityBlacklisted = false;
        if(getAccountType() == ACCOUNT_TYPE_UNIVERSITY) {
            uint256 localCourseID = degree.courseID;
            uint256 globalCourseID = universities[degree.issuer].courses[localCourseID].equivalency;
            for (uint256 i=0; i<universities[msg.sender].courses.length; i++) {
                if(universities[msg.sender].courses[i].equivalency == globalCourseID) {
                    equivalentCourseID = int256(i);
                }
            }
            for (uint256 i=0; i<universities[msg.sender].blacklistedCourseTemplates.length; i++) {
                if(universities[msg.sender].blacklistedCourseTemplates[i] == globalCourseID) {
                    isCourseBlacklisted = true;
                }
            }
            for (uint256 i=0; i<universities[msg.sender].blacklistedUniversities.length; i++) {
                if(universities[msg.sender].blacklistedUniversities[i] == degree.issuer) {
                    isUniversityBlacklisted = true;
                }
            }
        }
    }

    /*
     * This will create a courseTemplate with the need for voting.
     * After voting, the course will be verified and will be avilable to use.
     * This will just create a suggestion which will be opened for voting.
     * The duration of the voting will be for 1 year from suggestion.
     *
     * @param name        - Name of the courseTemplate standardized course.
     * @param description - Description of the Course.
     * @param duration    - Duration of the course in months
     * @validation
     * - Can be executed only by registered university
     * - Name cannot be empty.
     * - Duration of the course cannot be zero.
     */
    function suggestCourseTemplate(string calldata _name, string calldata _description, uint8 _duration) onlyUniversity() external returns(uint256 courseTemplateID) {
        require(bytes(_name).length > 0, "CourseTemplate Name cannot be empty");
        require(_duration > 0, "Duration of course cannot be zero");

        CourseTemplate storage courseTemplate = courseTemplates[courseTemplatesCount];
        courseTemplate.createdBy = msg.sender;
        courseTemplate.name = _name;
        courseTemplate.description = _description;
        courseTemplate.duration = _duration;
        courseTemplate.votingEndTimestamp = block.timestamp + 365 days;

        courseTemplatesCount++;
        courseTemplateID = courseTemplatesCount;
    }

    /*
     * Vote for a specific courseTemplate whether it is good or not.
     * The voting can only be done by registered universities once in the voting duration
     * The vote is a boolean yes/no whether that suggested courseTemplate should be accepted as a global standard or not.
     *
     * @param courseTemplateID - ID of the courseTemplate for which need to vote.
     * @param voteValue        - Boolean value of the vote whether to accept the suggested new course or not.
     * @return voteTimestamp
     * @validation
     * - This can only be executed by registered universities.
     * - The course Template should exist at that ID.
     * - Voting for that course template should be open.
     * - Double voting is not allowed.
     */
    function vote(uint256 courseTemplateID, bool voteValue) onlyUniversity() external returns(uint256 voteTimestamp) {
        require(bytes(courseTemplates[courseTemplateID].name).length > 0, "The course template does not exist");
        require(courseTemplates[courseTemplateID].votingEndTimestamp > block.timestamp, "The voting has already ended");
        require(courseTemplates[courseTemplateID].isVoted[msg.sender] == 0, "Double voting not allowed");
        
        voteTimestamp = block.timestamp;
        courseTemplates[courseTemplateID].isVoted[msg.sender] = voteTimestamp;

        if(voteValue) {
            courseTemplates[courseTemplateID].yesCount++;
        } else {
            courseTemplates[courseTemplateID].noCount++;
        }
    }

    /*
     * Gets the list of all available course template suggestions which are open for voting.
     * This is unique for all universities as it will remove from the list for suggestions which are already voted.
     *
     * @return CourseTemplatePublic[] - List of Course Templates (stripped for public usage).
     * @validation
     * - This function can only be executed by registered universities.
     */
    function getCourseTemplatesOpenForVoting() onlyUniversity() external view returns(CourseTemplatePublic[] memory courseTemplatePublic) {
        courseTemplatePublic = new CourseTemplatePublic[](courseTemplatesCount);
        uint256 counter = 0;
        for(uint256 i=0; i<courseTemplatesCount; i++) {
            if((courseTemplates[i].votingEndTimestamp > block.timestamp) && (courseTemplates[i].isVoted[msg.sender] == 0)) {
                courseTemplatePublic[counter] = CourseTemplatePublic(courseTemplates[i].name, courseTemplates[i].description, courseTemplates[i].duration);
                counter++;
            }
        }
    }

    /* 
     * This function ends the voting process.
     * This needs to be executed by creator of the suggested Course Template.
     * The voting will end only after the endtimestamp is passed.
     * Then the votes will be counted and the result will be assigned to the suggestion.
     * In case it is a draw in number of votes. The voting period is extended by another 30 days.
     * If the voting period has been extended, then final verification will not be counted and all three returns will be 0, 0, false.
     *
     * @param courseTemplateID - The ID of the course template for which voting should be ended.
     * @return uint256         - The count of yes votes. Universities which believe this should be a global standard.
     * @return uint256         - The count of no votes. Universities which believe this should not be a global standard.
     * @return bool            - Result of comparison whether the suggested courseTemplate is accepted by majority of universities or not.
     * @validations
     * - Only universities can execute this.
     * - The courseTemplateID needs to be a valid identifier.
     * - Voting cannot be ended twice.
     * - Sender needs to be the creator of the courseTemplate.
     */
    function endVoting(uint256 courseTemplateID) onlyUniversity() external returns(uint256 _yesCount, uint256 _noCount, bool _isVerified) {
        require(bytes(courseTemplates[courseTemplateID].name).length > 0, "The course template does not exist");
        require(courseTemplates[courseTemplateID].votingEndTimestamp > block.timestamp, "The voting has already ended");
        require(courseTemplates[courseTemplateID].createdBy == msg.sender, "Only creator can end voting");

        _yesCount = courseTemplates[courseTemplateID].yesCount;
        _noCount = courseTemplates[courseTemplateID].noCount;

        if(_yesCount > _noCount) {
            _isVerified = true;
        }else if(_yesCount < _noCount) {
            _isVerified = false;
        } else {
            courseTemplates[courseTemplateID].votingEndTimestamp = block.timestamp + 30 days;
            _yesCount = 0;
            _noCount = 0;
            _isVerified = false;
        }
        courseTemplates[courseTemplateID].isVerified = _isVerified;
    }

    /* 
     * This function ends the voting process explicitly. This does not check the endTimestamp.
     * This can only be executed by owner of this contract.
     * Then the votes will be counted and the result will be assigned to the suggestion.
     * In case it is a draw in number of votes. The voting period is extended by another 30 days.
     * However, if the owner wants, then the owner can give the decidingVote for clearing the draw. This is irrespective of double voting.
     * If the voting period has been extended, then final verification will not be counted and all three returns will be 0, 0, false.
     *
     * @param courseTemplateID - The ID of the course template for which voting should be ended.
     * @param useDecidingVote  - Whether use deciding vote to solve the draw (true) or extend the voting period (false).
     * @param decidingVote     - The deciding vote, only to be used in case there is draw in the number of votes.
     * @return uint256         - The count of yes votes. Universities which believe this should be a global standard.
     * @return uint256         - The count of no votes. Universities which believe this should not be a global standard.
     * @return bool            - Result of comparison whether the suggested courseTemplate is accepted by majority of universities or not.
     * @validations
     * - Only contract owner can execute this.
     * - The courseTemplateID needs to be a valid identifier.
     * - Voting cannot be ended twice.
     */
    function ownerEndVoting(uint256 courseTemplateID, bool useDecidingVote, bool decidingVote) onlyOwner() external returns(uint256 _yesCount, uint256 _noCount, bool _isVerified) {
        require(bytes(courseTemplates[courseTemplateID].name).length > 0, "The course template does not exist");
        require(courseTemplates[courseTemplateID].votingEndTimestamp > block.timestamp, "The voting has already ended");

        _yesCount = courseTemplates[courseTemplateID].yesCount;
        _noCount = courseTemplates[courseTemplateID].noCount;

        if(_yesCount > _noCount) {
            _isVerified = true;
        }else if(_yesCount < _noCount) {
            _isVerified = false;
        } else {
            if(useDecidingVote) {
                _isVerified = decidingVote;
                if(decidingVote) {
                    _yesCount++;
                    courseTemplates[courseTemplateID].yesCount = _yesCount;
                } else {
                    _noCount++;
                    courseTemplates[courseTemplateID].noCount = _noCount;
                }
            } else {
                courseTemplates[courseTemplateID].votingEndTimestamp = block.timestamp + 30 days;
                _yesCount = 0;
                _noCount = 0;
                _isVerified = false;
            }
        }
        courseTemplates[courseTemplateID].isVerified = _isVerified;
    }

    /*
     * This will create a courseTemplate without the need for voting.
     * That means, the courseTemplated created by this will already be verified.
     * This can only be executed by owner of this contract.
     *
     * @param name        - Name of the courseTemplate standardized course.
     * @param description - Description of the Course.
     * @param duration    - Duration of the course in months
     * @validation
     * - Can be executed only by the contract owner.
     * - Name cannot be empty.
     * - Duration of the course cannot be zero.
     */
    function createCourseTemplate(string calldata _name, string calldata _description, uint8 _duration) onlyOwner() external returns(uint256 courseTemplateID) {
        require(bytes(_name).length > 0, "CourseTemplate Name cannot be empty");
        require(_duration > 0, "Duration of course cannot be zero");

        CourseTemplate storage courseTemplate = courseTemplates[courseTemplatesCount];
        courseTemplate.createdBy = msg.sender;
        courseTemplate.name = _name;
        courseTemplate.description = _description;
        courseTemplate.duration = _duration;
        courseTemplate.votingEndTimestamp = block.timestamp;
        courseTemplate.isVerified = true;

        courseTemplatesCount++;
        courseTemplateID = courseTemplatesCount;
    }

    /*
     * Increments the total number of degrees issued over time by 1.
     * Can only be called from within this contract.
     */
    function incrementIssuedDegreeCount() private {
        issuedDegreeCount++;
    }

    /*
     * Increments the total number of registered universities on the application by 1.
     * This can only be called from within this contract.
     */
    function incrementUniversityCount() private {
        universityCount++;
    }

    /*
     * Increments the total number of registered students on the application by 1.
     * This can only be called from within this contract.
     */
    function incrementStudentCount() private {
        studentCount++;
    }

    /*
     * Get the type of user currently connected to the application.
     * 
     * @return uint8 - 101 for University and 102 for Student.
     */
    function getAccountType() public view returns(uint8) {
        if(universities[msg.sender].establishedAt > 0) {
            return ACCOUNT_TYPE_UNIVERSITY;
        }
        return ACCOUNT_TYPE_STUDENT;
    }

    /*
     * Return all information about the current Student Account.
     *
     * @return Student  - Object of the Student profile.     
     */
    function getDetailsStudent() external view returns(Student memory) {
        return getDetailsStudent(msg.sender);
    }

    /*
     * Return all information about the requested Student Account.
     *
     * @param student   - Address of the Student whose account needs to be fetched.
     * @return Student  - Object of the student Profile  
     */
    function getDetailsStudent(address student) public view returns(Student memory) {
        return students[student];
    }

    /*
     * Return all information about the current University Account.
     *
     * @return University - Object of the Requested university
     * @validations
     * - The current university needs to be registered.
     */
    function getDetailsUniversity() external view returns(University memory) {
        return getDetailsUniversity(msg.sender);
    }

    /*
     * Return all information about the requested University Account.
     *
     * @param university  - Address of the University whose account needs to be fetched.
     * @return University - Object of the University Profile.  
     */
    function getDetailsUniversity(address university) public view returns(University memory) {
        require(isValidUniversity(university), "University is not registered yet");
        return universities[msg.sender];
    }

    /*
     * Check whether the sender of the message is a valid university or not.
     * This function can only be called from within this contract.
     * 
     * @return bool - Whether the current sender is a valid university or not.
     */
    function isValidUniversity() private view returns(bool) {
        return isValidUniversity(msg.sender);
    }

    /*
     * Check whether the university is valid or not.
     * This function can only be called from within this contract.
     * 
     * @param university - Address of the university to be checked.
     * @return bool      - Whether the university is valid or not.
     */
    function isValidUniversity(address university) private view returns(bool) {
        if(universities[university].establishedAt > 0) {
            return true;
        }
        return false;
    }

    /*
     * Get valid courseTemplates which a university can map to.
     * This is on a per university basis as this also considers blacklisted coursetemplates.
     * The returned list is total verified courseTemplate (minus) blacklistedCourseTemplates.
     * Therefore naming it as valid as verified means something else in this context.
     *
     * @return CourseTemplate[] - List of valid courseTemplates which can be used by the university.
    */
    function getValidCourseTemplates() external view returns(CourseTemplatePublic[] memory _courseTemplates) {
        _courseTemplates = new CourseTemplatePublic[](courseTemplatesCount);
        uint256 counter = 0;
        for (uint256 i=0; i < courseTemplatesCount; i++) {
            if(courseTemplates[i].isVerified && !isBlackListedCourseTemplate(i)) {
                _courseTemplates[counter] = CourseTemplatePublic(courseTemplates[i].name, courseTemplates[i].description, courseTemplates[i].duration);
                counter++;
            }
        }
    }

    /*
     * Access Modifier which can be used to keep the code simple and clean.
     * Helps remove repeated require checks for whether the user is a university or not.   
     */
    modifier onlyUniversity(){
        require(isValidUniversity(), "Unauthorized, not a registered University");
        _;
    }

    /*
     * Access Modifier which to check whether the user is owner or not.
     * This is checked before executing any transaction with owner superpower.
     */
    modifier onlyOwner(){
        require(msg.sender == owner, "Not owner, unauthorized");
        _;
    }

    /* END OF CONTRACT */
}