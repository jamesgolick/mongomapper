require 'test_helper'

class DocumentTest < Test::Unit::TestCase
  context "The Document Class" do
    setup do
      @document = Class.new
      @document.class_eval { include MongoMapper::Document }
    end

    should "should be able to define a key" do
      key = @document.key(:name, String)
      key.name.should == 'name'
      key.type.should == String
      key.should be_instance_of(MongoMapper::Key)
    end
    
    should "know what keys have been defined" do
      @document.key(:name, String)
      @document.key(:age, Integer)
      @document.keys['name'].name.should == 'name'
      @document.keys['name'].type.should == String
      @document.keys['age'].name.should == 'age'
      @document.keys['age'].type.should == Integer
    end
    
    should "use default database by default" do
      @document.database.should == MongoMapper.database
    end
    
    should "have a connection" do
      @document.connection.should be_instance_of(XGen::Mongo::Driver::Mongo)
    end
    
    should "allow setting different connection without affecting the default" do
      conn = XGen::Mongo::Driver::Mongo.new
      @document.connection conn
      @document.connection.should == conn
      @document.connection.should_not == MongoMapper.connection
    end
    
    should "allow setting a different database without affecting the default" do
      @document.database AlternateDatabase
      @document.database.name.should == AlternateDatabase
      
      another_document = Class.new
      another_document.class_eval { include MongoMapper::Document }
      another_document.database.should == MongoMapper.database
    end
    
    should "default collection name to class name tableized" do
      @document.collection.should be_instance_of(XGen::Mongo::Driver::Collection)
      @document.collection.name.should == 'classes'
    end
    
    should "allow setting the collection name" do
      @document.collection('foobar')
      @document.collection.should be_instance_of(XGen::Mongo::Driver::Collection)
      @document.collection.name.should == 'foobar'
    end
  end # Document class  
  
  context "Database operations" do
    setup do
      @document = Class.new
      @document.class_eval do
        include MongoMapper::Document
        collection 'users'
        
        key :fname, String
        key :lname, String
        key :age, Integer
      end
      
      @document.collection.clear
    end
    
    context "Creating a single document" do
      setup do
        @record = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
      end

      should "create a document in correct collection" do
        @document.count.should == 1
      end

      should "automatically set id" do
        @record.id.should_not be_nil
        @record.id.size.should == 24
      end

      should "return instance of document" do
        @record.should be_instance_of(@document)
        @record.fname.should == 'John'
        @record.lname.should == 'Nunemaker'
        @record.age.should == 27
      end
    end    
    
    context "Creating multiple documents" do
      setup do
        @records = @document.create([
          {:fname => 'John', :lname => 'Nunemaker', :age => '27'},
          {:fname => 'Steve', :lname => 'Smith', :age => '28'},
        ])
      end

      should "create multiple documents" do
        @document.count.should == 2
      end
      
      should "return an array of doc instances" do
        @records.map do |record|
          record.should be_instance_of(@document)
        end
      end
    end
    
    context "Updating a document" do
      setup do
        doc = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @record = @document.update(doc.id, {:age => 40})
      end

      should "update attributes provided" do
        @record.age.should == 40
      end
      
      should "not update existing attributes that were not set to update" do
        @record.fname.should == 'John'
        @record.lname.should == 'Nunemaker'
      end
      
      should "not create new document" do
        @document.count.should == 1
      end
    end
    
    should "raise error when updating single doc if not provided id and attributes" do
      doc = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
      lambda { @document.update }.should raise_error(ArgumentError)
      lambda { @document.update(doc.id) }.should raise_error(ArgumentError)
      lambda { @document.update(doc.id, [1]) }.should raise_error(ArgumentError)
    end
    
    context "Updating multiple documents" do
      setup do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        
        @records = @document.update({
          @doc1.id => {:age => 30},
          @doc2.id => {:age => 30},
        })
      end

      should "not create any new documents" do
        @document.count.should == 2
      end
      
      should "should return an array of doc instances" do
        @records.map do |record|
          record.should be_instance_of(@document)
        end
      end
      
      should "update the documents" do
        @document.find(@doc1.id).age.should == 30
        @document.find(@doc2.id).age.should == 30
      end
    end
    
    should "raise error when updating multiple documents if not a hash" do
      lambda { @document.update([1, 2]) }.should raise_error(ArgumentError)
    end
    
    context "Finding documents" do
      setup do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @doc3 = @document.create({:fname => 'Steph', :lname => 'Nunemaker', :age => '26'})
      end
      
      should "raise document not found if nothing provided" do
        lambda { @document.find }.should raise_error(MongoMapper::DocumentNotFound)
      end
      
      context "with a single id" do
        should "work" do
          @document.find(@doc1.id).should == @doc1
        end
        
        should "raise error if document not found" do
          lambda { @document.find(1) }.should raise_error(MongoMapper::DocumentNotFound)
        end
      end
      
      context "with multiple id's" do
        should "work as arguments" do
          @document.find(@doc1.id, @doc2.id).should == [@doc1, @doc2]
        end
        
        should "work as array" do
          @document.find([@doc1.id, @doc2.id]).should == [@doc1, @doc2]
        end
      end
      
      context "with :all" do
        should "find all documents" do
          @document.find(:all).should == [@doc1, @doc2, @doc3]
        end
        
        should "be able to add conditions" do
          @document.find(:all, :conditions => {:fname => 'John'}).should == [@doc1]
        end
      end
      
      context "with :first" do
        should "find first document" do
          @document.find(:first).should == @doc1
        end
      end
      
      context "with :last" do
        should "find last document" do
          @document.find(:last).should == @doc3
        end
      end
    end # finding documents
    
    context "Finding document by id" do
      setup do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
      end

      should "be able to find by id" do
        @document.find_by_id(@doc1.id).should == @doc1
        @document.find_by_id(@doc2.id).should == @doc2
      end
      
      should "return nil if document not found" do
        @document.find_by_id(1234).should be(nil)
      end
    end
    
    context "Deleting a document" do
      setup do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @document.delete(@doc1.id)
      end

      should "remove document from collection" do
        @document.count.should == 1
      end
      
      should "not remove other documents" do
        @document.find(@doc2.id).should_not be(nil)
      end
    end
    
    context "Deleting multiple documents" do
      should "work with multiple arguments" do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @doc3 = @document.create({:fname => 'Steph', :lname => 'Nunemaker', :age => '26'})
        @document.delete(@doc1.id, @doc2.id)
        
        @document.count.should == 1
      end
      
      should "work with array as argument" do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @doc3 = @document.create({:fname => 'Steph', :lname => 'Nunemaker', :age => '26'})
        @document.delete([@doc1.id, @doc2.id])
        
        @document.count.should == 1
      end
    end
    
    context "Deleting all documents" do
      setup do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @doc3 = @document.create({:fname => 'Steph', :lname => 'Nunemaker', :age => '26'})
      end

      should "remove all documents when given no conditions" do
        @document.delete_all
        @document.count.should == 0
      end
      
      should "only remove matching documents when given conditions" do
        @document.delete_all({:fname => 'John'})
        @document.count.should == 2
      end
    end
    
    context "Destroying a document" do
      setup do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @document.destroy(@doc1.id)
      end

      should "remove document from collection" do
        @document.count.should == 1
      end
      
      should "not remove other documents" do
        @document.find(@doc2.id).should_not be(nil)
      end
    end
    
    context "Destroying multiple documents" do
      should "work with multiple arguments" do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @doc3 = @document.create({:fname => 'Steph', :lname => 'Nunemaker', :age => '26'})
        @document.destroy(@doc1.id, @doc2.id)
        
        @document.count.should == 1
      end
      
      should "work with array as argument" do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @doc3 = @document.create({:fname => 'Steph', :lname => 'Nunemaker', :age => '26'})
        @document.destroy([@doc1.id, @doc2.id])
        
        @document.count.should == 1
      end
    end
    
    context "Destroying all documents" do
      setup do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @doc3 = @document.create({:fname => 'Steph', :lname => 'Nunemaker', :age => '26'})
      end

      should "remove all documents when given no conditions" do
        @document.destroy_all
        @document.count.should == 0
      end
      
      should "only remove matching documents when given conditions" do
        @document.destroy_all(:fname => 'John')
        @document.count.should == 2
        @document.destroy_all(:age => 26)
        @document.count.should == 1
      end
    end
    
    context "Counting documents in collection" do
      setup do
        @doc1 = @document.create({:fname => 'John', :lname => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:fname => 'Steve', :lname => 'Smith', :age => '28'})
        @doc3 = @document.create({:fname => 'Steph', :lname => 'Nunemaker', :age => '26'})
      end

      should "count all with no arguments" do
        @document.count.should == 3
      end
      
      should "return 0 if there are no documents in the collection" do
        @document.delete_all
        @document.count.should == 0
      end
      
      should "return count for matching documents if conditions provided" do
        @document.count(:age => 27).should == 1
      end
    end
    
  end # Database operations
  
  context "An instance of a document" do
    setup do
      @document = Class.new
      @document.class_eval do
        include MongoMapper::Document
        
        key :name, String
        key :age, Integer
      end
      @document.collection.clear
    end
    
    should "have access to the class's collection" do
      doc = @document.new
      doc.collection.should == @document.collection
    end
    
    should "automatically have an _id key" do
      @document.keys.keys.should include('_id')
    end
    
    context "new_record?" do
      should "be true if no id" do
        @document.new.new_record?.should be(true)
      end
      
      should "be true if has id but id not in database" do
        @document.new('_id' => 1).new_record?.should be(true)
      end
      
      should "be false if has id and id is in database" do
        doc = @document.create(:name => 'John Nunemaker', :age => 27)
        doc.new_record?.should be(false)
      end
    end
    
    context "when initialized" do
      should "accept a hash that sets keys and values" do
        doc = @document.new(:name => 'John', :age => 23)
        doc.attributes.should == {'name' => 'John', 'age' => 23}
      end
      
      should "silently reject keys that have not been defined" do
        doc = @document.new(:foobar => 'baz')
        doc.attributes.should == {}
      end
    end
    
    context "mass assigning keys" do
      should "update values for keys provided" do
        doc = @document.new(:name => 'foobar', :age => 10)
        doc.attributes = {:name => 'new value', :age => 5}
        doc.attributes[:name].should == 'new value'
        doc.attributes[:age].should == 5
      end

      should "not update values for keys that were not provided" do
        doc = @document.new(:name => 'foobar', :age => 10)
        doc.attributes = {:name => 'new value'}
        doc.attributes[:name].should == 'new value'
        doc.attributes[:age].should == 10
      end

      should "ignore keys that do not exist" do
        doc = @document.new(:name => 'foobar', :age => 10)
        doc.attributes = {:name => 'new value', :foobar => 'baz'}
        doc.attributes[:name].should == 'new value'
        doc.attributes[:foobar].should be(nil)
      end

      should "typecast key values" do
        doc = @document.new(:name => 1234, :age => '21')
        doc.name.should == '1234'
        doc.age.should == 21
      end
    end

    context "requesting keys" do
      should "default to empty hash" do
        doc = @document.new
        doc.attributes.should == {}
      end

      should "return all keys that aren't nil" do
        doc = @document.new(:name => 'string', :age => nil)
        doc.attributes.should == {'name' => 'string'}
      end
    end

    context "key shorcuts" do
      should "be able to read key with []" do
        doc = @document.new(:name => 'string')
        doc[:name].should == 'string'
      end

      should "be able to write key value with []=" do
        doc = @document.new
        doc[:name] = 'string'
        doc[:name].should == 'string'
      end
    end

    context "indifferent access" do
      should "be enabled for keys" do
        doc = @document.new(:name => 'string')
        doc.attributes[:name].should == 'string'
        doc.attributes['name'].should == 'string'
      end
    end

    context "reading an attribute" do
      should "work for defined keys" do
        doc = @document.new(:name => 'string')
        doc.name.should == 'string'
      end

      should "raise no method error for undefined keys" do
        doc = @document.new
        lambda { doc.fart }.should raise_error(NoMethodError)
      end
      
      should "know if reader defined" do
        doc = @document.new
        doc.reader?('name').should be(true)
        doc.reader?(:name).should be(true)
        doc.reader?('age').should be(true)
        doc.reader?(:age).should be(true)
        doc.reader?('foobar').should be(false)
        doc.reader?(:foobar).should be(false)
      end
      
      should "be accissible for use in the model" do
        @document.class_eval do
          def name_and_age
            "#{read_attribute(:name)} (#{read_attribute(:age)})"
          end
        end
                
        doc = @document.new(:name => 'John', :age => 27)
        doc.name_and_age.should == 'John (27)'
      end
    end

    context "writing an attribute" do
      should "work for defined keys" do
        doc = @document.new
        doc.name = 'John'
        doc.name.should == 'John'
      end

      should "raise no method error for undefined keys" do
        doc = @document.new
        lambda { doc.fart = 'poof!' }.should raise_error(NoMethodError)
      end

      should "typecast value" do
        doc = @document.new
        doc.name = 1234
        doc.name.should == '1234'
        doc.age = '21'
        doc.age.should == 21
      end
      
      should "know if writer defined" do
        doc = @document.new
        doc.writer?('name').should be(true)
        doc.writer?('name=').should be(true)
        doc.writer?(:name).should be(true)
        doc.writer?('age').should be(true)
        doc.writer?('age=').should be(true)
        doc.writer?(:age).should be(true)
        doc.writer?('foobar').should be(false)
        doc.writer?('foobar=').should be(false)
        doc.writer?(:foobar).should be(false)
      end
      
      should "be accessible for use in the model" do
        @document.class_eval do          
          def name_and_age=(new_value)
            new_value.match(/([^\(\s]+) \((.*)\)/)
            write_attribute :name, $1
            write_attribute :age, $2
          end
        end
                
        doc = @document.new
        doc.name_and_age = 'Frank (62)'
        doc.name.should == 'Frank'
        doc.age.should == 62
      end
    end # writing an attribute
    
    context "equality" do
      should "be equal if id and class are the same" do
        (@document.new('_id' => 1) == @document.new('_id' => 1)).should be(true)
      end
      
      should "not be equal if class same but id different" do
        (@document.new('_id' => 1) == @document.new('_id' => 2)).should be(false)
      end
      
      should "not be equal if id same but class different" do
        @another_document = Class.new
        @another_document.class_eval { include MongoMapper::Document }
        
        (@document.new('_id' => 1) == @another_document.new('_id' => 1)).should be(false)
      end
    end
    
    context "Saving a new document" do
      setup do
        @doc = @document.new(:name => 'John Nunemaker', :age => '27')
        @doc.save
      end

      should "insert document into the collection" do
        @document.count.should == 1
      end
      
      should "assign an id for the document" do
        @doc.id.should_not be(nil)
        @doc.id.size.should == 24
      end
      
      should "save attributes" do
        @doc.name.should == 'John Nunemaker'
        @doc.age.should == 27
      end
      
      should "update attributes in the database" do
        from_db = @document.find(@doc.id)
        from_db.should == @doc
        from_db.name.should == 'John Nunemaker'
        from_db.age.should == 27
      end
    end
    
    context "Saving an existing document" do
      setup do
        @doc = @document.create(:name => 'John Nunemaker', :age => '27')
        @doc.name = 'John Doe'
        @doc.age = 30
        @doc.save
      end

      should "not insert document into collection" do
        @document.count.should == 1
      end
      
      should "update attributes" do
        @doc.name.should == 'John Doe'
        @doc.age.should == 30
      end
      
      should "update attributes in the database" do
        from_db = @document.find(@doc.id)
        from_db.name.should == 'John Doe'
        from_db.age.should == 30
      end
    end
    
    context "Calling update attributes on a new document" do
      setup do
        @doc = @document.new(:name => 'John Nunemaker', :age => '27')
        @doc.update_attributes(:name => 'John Doe', :age => 30)
      end

      should "insert document into the collection" do
        @document.count.should == 1
      end
      
      should "assign an id for the document" do
        @doc.id.should_not be(nil)
        @doc.id.size.should == 24
      end
      
      should "save attributes" do
        @doc.name.should == 'John Doe'
        @doc.age.should == 30
      end
      
      should "update attributes in the database" do
        from_db = @document.find(@doc.id)
        from_db.should == @doc
        from_db.name.should == 'John Doe'
        from_db.age.should == 30
      end
    end
    
    context "Updating an existing document using update attributes" do
      setup do
        @doc = @document.create(:name => 'John Nunemaker', :age => '27')
        @doc.update_attributes(:name => 'John Doe', :age => 30)
      end

      should "not insert document into collection" do
        @document.count.should == 1
      end
      
      should "update attributes" do
        @doc.name.should == 'John Doe'
        @doc.age.should == 30
      end
      
      should "update attributes in the database" do
        from_db = @document.find(@doc.id)
        from_db.name.should == 'John Doe'
        from_db.age.should == 30
      end
    end
    
    context "Destroying a document that exists" do
      setup do
        @doc = @document.create(:name => 'John Nunemaker', :age => '27')
        @doc.destroy
      end

      should "remove the document from the collection" do
        @document.count.should == 0
      end
      
      should "raise error if assignment is attempted" do
        lambda { @doc.name = 'Foo' }.should raise_error(TypeError)
      end
    end
    
    context "Destroying a document that is a new record" do
      setup do
        setup do
          @doc = @document.new(:name => 'John Nunemaker', :age => '27')
          @doc.destroy
        end

        should "not affect collection count" do
          @document.collection.count.should == 0
        end

        should "raise error if assignment is attempted" do
          lambda { @doc.name = 'Foo' }.should raise_error(TypeError)
        end
      end
    end
    
    context "timestamping" do
      should "set created_at and updated_at on create" do
        doc = @document.new(:name => 'John Nunemaker', :age => 27)
        doc.created_at.should be(nil)
        doc.updated_at.should be(nil)
        doc.save
        doc.created_at.should_not be(nil)
        doc.updated_at.should_not be(nil)
      end
      
      should "set updated_at on update but leave created_at alone" do
        doc = @document.create(:name => 'John Nunemaker', :age => 27)
        old_created_at = doc.created_at
        old_updated_at = doc.updated_at
        doc.name = 'John Doe'
        doc.save
        doc.created_at.should == old_created_at
        doc.updated_at.should_not == old_updated_at
      end
    end
    
  end # instance of a document
end # DocumentTest