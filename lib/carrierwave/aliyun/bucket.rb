module CarrierWave
  module Aliyun
    class Bucket
      PATH_PREFIX = %r{^/}

      def initialize(uploader)
        @aliyun_access_id    = uploader.aliyun_access_id
        @aliyun_access_key   = uploader.aliyun_access_key
        @aliyun_bucket       = uploader.aliyun_bucket
        @aliyun_area         = uploader.aliyun_area || 'cn-hangzhou'
        @aliyun_private_read = uploader.aliyun_private_read
        @aliyun_internal     = uploader.aliyun_internal

        # Host for get request
        @aliyun_host = uploader.aliyun_host || "https://#{@aliyun_bucket}.oss-#{@aliyun_area}.aliyuncs.com"

        unless @aliyun_host.include?('//')
          raise "config.aliyun_host requirement include // http:// or https://, but you give: #{@aliyun_host}"
        end
      end

      # 上传文件
      # params:
      # - path - remote 存储路径
      # - file - 需要上传文件的 File 对象
      # - opts:
      #   - content_type - 上传文件的 MimeType，默认 `image/jpg`
      #   - content_disposition - Content-Disposition
      # returns:
      # 图片的下载地址
      def put(path, file, opts = {})
        path.sub!(PATH_PREFIX, '')

        headers = {}
        headers['Content-Type'] = opts[:content_type] || 'image/jpg'
        content_disposition = opts[:content_disposition]
        if content_disposition
          headers['Content-Disposition'] = content_disposition
        end

        res = oss_upload_client.put_object(path, file: file.path, headers: headers)
        if res
          path_to_url(path)
        else
          raise 'Put file failed'
        end
      end

      # 读取文件
      # params:
      # - path - remote 存储路径
      # returns:
      # file data
      def get(path)
        path.sub!(PATH_PREFIX, '')
        content = ''
        res = oss_upload_client.get_object(path) { |c| content << c }
        if res
          return res.merge(body: content)
        else
          raise 'Get content faild'
        end
      end

      # 删除 Remote 的文件
      #
      # params:
      # - path - remote 存储路径
      #
      # returns:
      # 图片的下载地址
      def delete(path)
        path.sub!(PATH_PREFIX, '')
        res = oss_upload_client.delete_object(path)
        if res
          return path_to_url(path)
        else
          raise 'Delete failed'
        end
      end

      ##
      # 根据配置返回完整的上传文件的访问地址
      def path_to_url(path, opts = {})
        if opts[:thumb]
          thumb_path = [path, opts[:thumb]].join('')
          [@aliyun_host, thumb_path].join('/')
        else
          [@aliyun_host, path].join('/')
        end
      end

      # 私有空间访问地址，会带上实时算出的 token 信息
      # 有效期 3600s
      def private_get_url(path, opts = {})
        path.sub!(PATH_PREFIX, '')
        url = ''
        if opts[:thumb]
          thumb_path = [path, opts[:thumb]].join('')
          url = img_client.bucket_get_object_share_link(thumb_path, 3600)
        else
          url = oss_client.bucket_get_object_share_link(path, 3600)
        end
        url.gsub('http://', 'https://')
      end

      def head(path)
        oss_client.get_object(path)
      end

      private

      def oss_client
        return @oss_client if defined?(@oss_client)

        @oss_client = ::Aliyun::OSS::Client.new({
          endpoint: "oss-#{@aliyun_area}.aliyuncs.com",
          access_key_id: @aliyun_access_id,
          access_key_secret: @aliyun_access_key,
        }).get_bucket(@aliyun_bucket)
      end

      def img_client
        return @img_client if defined?(@img_client)

        @img_client = ::Aliyun::OSS::Client.new({
          endpoint: "img-#{@aliyun_area}.aliyuncs.com",
          access_key_id: @aliyun_access_id,
          access_key_secret: @aliyun_access_key,
        }).get_bucket(@aliyun_bucket)
      end

      def oss_upload_client
        return @oss_upload_client if defined?(@oss_upload_client)

        host = if @aliyun_internal
                 "oss-#{@aliyun_area}-internal.aliyuncs.com"
               else
                 "oss-#{@aliyun_area}.aliyuncs.com"
               end

        @oss_upload_client = ::Aliyun::OSS::Client.new({
          endpoint: host,
          access_key_id: @aliyun_access_id,
          access_key_secret: @aliyun_access_key,
        }).get_bucket(@aliyun_bucket)
      end
    end
  end
end
