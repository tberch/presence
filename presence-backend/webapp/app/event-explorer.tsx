import React, { useState } from 'react';
import { Search, Filter, Map, List, Music, ChevronDown, Calendar, Clock, Volume2, Headphones, Star, Users } from 'lucide-react';

const EventExplorer = () => {
  const [viewMode, setViewMode] = useState('list');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [filterOpen, setFilterOpen] = useState(false);
  
  const categories = [
    { id: 'all', name: 'All Events', icon: Music },
    { id: 'music', name: 'Live Music', icon: Music },
    { id: 'speech', name: 'Speeches', icon: Music },
    { id: 'nature', name: 'Nature Sounds', icon: Music },
    { id: 'city', name: 'City Sounds', icon: Music },
  ];
  
  const events = [
    {
      id: 1,
      title: 'Central Park Jazz Quartet',
      category: 'music',
      location: 'Great Lawn, Central Park',
      distance: '0.8 miles away',
      time: 'Live now • Started 45 min ago',
      listeners: 87,
      rating: 4.8,
      reviews: 24,
      imageUrl: '/api/placeholder/400/200'
    },
    {
      id: 2,
      title: 'Ambient City Sounds at Times Square',
      category: 'city',
      location: 'Times Square',
      distance: '1.2 miles away',
      time: 'Live now • Started 20 min ago',
      listeners: 45,
      rating: 4.5,
      reviews: 12,
      imageUrl: '/api/placeholder/400/200'
    },
    {
      id: 3,
      title: 'Dawn Chorus at Brooklyn Botanic Garden',
      category: 'nature',
      location: 'Brooklyn Botanic Garden',
      distance: '3.5 miles away',
      time: 'Scheduled for tomorrow, 6:00 AM',
      listeners: 0,
      rating: 4.9,
      reviews: 31,
      imageUrl: '/api/placeholder/400/200'
    },
    {
      id: 4,
      title: 'Mayor\'s Address on Urban Development',
      category: 'speech',
      location: 'City Hall',
      distance: '2.1 miles away',
      time: 'Starting in 30 minutes',
      listeners: 124,
      rating: 4.2,
      reviews: 8,
      imageUrl: '/api/placeholder/400/200'
    },
    {
      id: 5,
      title: 'NYU String Quartet Performance',
      category: 'music',
      location: 'Washington Square Park',
      distance: '0.5 miles away',
      time: 'Live now • Started 10 min ago',
      listeners: 56,
      rating: 4.7,
      reviews: 15,
      imageUrl: '/api/placeholder/400/200'
    }
  ];

  const filteredEvents = selectedCategory === 'all' 
    ? events 
    : events.filter(event => event.category === selectedCategory);

  const toggleFilter = () => {
    setFilterOpen(!filterOpen);
  };

  return (
    <div className="bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="bg-white shadow p-4">
        <div className="relative">
          <input
            type="text"
            placeholder="Search audio events..."
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <Search className="absolute left-3 top-2.5 text-gray-400 h-5 w-5" />
        </div>
        
        {/* Categories */}
        <div className="flex overflow-x-auto py-4 space-x-2 no-scrollbar">
          {categories.map(category => (
            <button
              key={category.id}
              className={`flex items-center px-4 py-2 rounded-full whitespace-nowrap ${
                selectedCategory === category.id
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-800'
              }`}
              onClick={() => setSelectedCategory(category.id)}
            >
              <category.icon className="h-4 w-4 mr-2" />
              {category.name}
            </button>
          ))}
        </div>
        
        {/* View toggles and filters */}
        <div className="flex justify-between items-center pt-2">
          <div className="flex space-x-2">
            <button
              className={`p-2 rounded-md ${viewMode === 'list' ? 'bg-gray-200' : 'bg-white'}`}
              onClick={() => setViewMode('list')}
            >
              <List className="h-5 w-5 text-gray-700" />
            </button>
            <button
              className={`p-2 rounded-md ${viewMode === 'map' ? 'bg-gray-200' : 'bg-white'}`}
              onClick={() => setViewMode('map')}
            >
              <Map className="h-5 w-5 text-gray-700" />
            </button>
          </div>
          
          <button
            className="flex items-center px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md"
            onClick={toggleFilter}
          >
            <Filter className="h-4 w-4 mr-1" />
            Filter
            <ChevronDown className={`h-4 w-4 ml-1 transition-transform ${filterOpen ? 'rotate-180' : ''}`} />
          </button>
        </div>
        
        {/* Filters panel - shown when filterOpen is true */}
        {filterOpen && (
          <div className="bg-white p-4 mt-2 rounded-md shadow border border-gray-200">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Distance</label>
                <select className="w-full p-2 border border-gray-300 rounded-md">
                  <option>Any distance</option>
                  <option>Under 1 mile</option>
                  <option>1-5 miles</option>
                  <option>5-10 miles</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Time</label>
                <select className="w-full p-2 border border-gray-300 rounded-md">
                  <option>Any time</option>
                  <option>Live now</option>
                  <option>Starting soon</option>
                  <option>Later today</option>
                  <option>Tomorrow</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Rating</label>
                <select className="w-full p-2 border border-gray-300 rounded-md">
                  <option>Any rating</option>
                  <option>4+ stars</option>
                  <option>3+ stars</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Listeners</label>
                <select className="w-full p-2 border border-gray-300 rounded-md">
                  <option>Any amount</option>
                  <option>10+ listeners</option>
                  <option>50+ listeners</option>
                  <option>100+ listeners</option>
                </select>
              </div>
            </div>
            <div className="mt-4 flex justify-end space-x-2">
              <button className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md">
                Reset
              </button>
              <button className="px-4 py-2 text-sm text-white bg-blue-600 rounded-md">
                Apply Filters
              </button>
            </div>
          </div>
        )}
      </div>
      
      {/* Content */}
      <div className="p-4">
        {viewMode === 'list' ? (
          <div className="space-y-4">
            {filteredEvents.map(event => (
              <div key={event.id} className="bg-white rounded-lg shadow overflow-hidden">
                <div className="h-48 bg-gray-300 overflow-hidden relative">
                  <img src={event.imageUrl} alt={event.title} className="w-full h-full object-cover" />
                  <div className="absolute top-2 right-2 bg-blue-600 text-white rounded-full px-3 py-1 text-xs font-medium">
                    {event.category.charAt(0).toUpperCase() + event.category.slice(1)}
                  </div>
                </div>
                <div className="p-4">
                  <h3 className="font-semibold text-lg text-gray-900">{event.title}</h3>
                  <div className="mt-2 space-y-2">
                    <div className="flex items-center text-sm text-gray-600">
                      <Map className="h-4 w-4 mr-2" />
                      <div>
                        <div>{event.location}</div>
                        <div className="text-xs text-gray-500">{event.distance}</div>
                      </div>
                    </div>
                    <div className="flex items-center text-sm text-gray-600">
                      <Clock className="h-4 w-4 mr-2" />
                      <span>{event.time}</span>
                    </div>
                  </div>
                  <div className="mt-3 flex justify-between items-center">
                    <div className="flex items-center">
                      <div className="flex items-center mr-4">
                        <Users className="h-4 w-4 mr-1 text-gray-500" />
                        <span className="text-sm text-gray-600">{event.listeners} listening</span>
                      </div>
                      <div className="flex items-center">
                        <Star className="h-4 w-4 mr-1 text-yellow-500" />
                        <span className="text-sm text-gray-600">{event.rating} ({event.reviews})</span>
                      </div>
                    </div>
                    <button className="flex items-center justify-center h-8 w-8 rounded-full bg-blue-600 text-white">
                      <Headphones className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="bg-white rounded-lg shadow overflow-hidden h-96 flex items-center justify-center">
            <div className="text-center text-gray-500">
              <Map className="h-12 w-12 mx-auto mb-2" />
              <p>Map view would display events geographically</p>
              <p className="text-sm">(Map integration to be implemented)</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default EventExplorer;
