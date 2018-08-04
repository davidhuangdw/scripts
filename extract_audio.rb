#!/usr/bin/env ruby

require 'streamio-ffmpeg'
files = Dir.glob('*.{mp4,avi,flv,rmvb,mkv}')
files.each do |f|
  movie = FFMPEG::Movie.new(f)
  options = %w[-acodec copy]
  movie.transcode(movie.path+'.'+movie.audio_codec, options)
end
